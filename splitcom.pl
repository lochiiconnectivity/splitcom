#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

# Command line arguments
my $input_file;
my $output_file;
my $remove_person;

# Parse command line options
GetOptions(
    "i=s" => \$input_file,
    "o=s" => \$output_file,
    "p=s" => \$remove_person
) or die "Error in command line arguments\n";

# Check if required arguments are provided
die "Usage: $0 -i <input_file> -o <output_file> -p <person_id>\n" 
    unless $input_file && $output_file && $remove_person;

# Read the GEDCOM file
open my $in_fh, '<', $input_file or die "Cannot open input file $input_file: $!";
my @lines = <$in_fh>;
close $in_fh;

# Data structures
my %individuals;  # Hash to store all individuals
my %families;     # Hash to store all families
my %keep_list;    # Hash to track individuals to keep
my %to_remove;    # Hash to track individuals and their ancestors to remove

# First pass: Organize data into individuals and families
my $current_record = '';
my $current_id = '';

foreach my $line (@lines) {
    chomp $line;
    
    # Skip empty lines
    next if $line =~ /^\s*$/;
    
    # Parse the GEDCOM level, tag, and value
    if ($line =~ /^(\d+)\s+(\@(\w+)\@)?\s*(\w+)(.*)/) {
        my $level = $1;
        my $tag = $4;
        my $value = $5;
        my $xref = $3;
        
        $value =~ s/^\s+//;  # Trim leading spaces
        
        # New record
        if ($level == 0) {
            if ($tag eq 'INDI') {
                $current_record = 'INDI';
                $current_id = $xref;
                $individuals{$current_id} = { lines => [$line] };
            } elsif ($tag eq 'FAM') {
                $current_record = 'FAM';
                $current_id = $xref;
                $families{$current_id} = { lines => [$line], HUSB => [], WIFE => [], CHIL => [] };
            } elsif ($xref && $value =~ /INDI/) {
                $current_record = 'INDI';
                $current_id = $xref;
                $individuals{$current_id} = { lines => [$line] };
            } elsif ($xref && $value =~ /FAM/) {
                $current_record = 'FAM';
                $current_id = $xref;
                $families{$current_id} = { lines => [$line], HUSB => [], WIFE => [], CHIL => [] };
            } else {
                $current_record = 'OTHER';
                $current_id = '';
            }
        } 
        # Add line to current record
        elsif ($current_record eq 'INDI') {
            push @{$individuals{$current_id}{lines}}, $line;
            
            # Store parent family information
            if ($tag eq 'FAMC' && $value =~ /\@(\w+)\@/) {
                $individuals{$current_id}{FAMC} ||= [];
                push @{$individuals{$current_id}{FAMC}}, $1;
            }
            # Store spouse family information
            elsif ($tag eq 'FAMS' && $value =~ /\@(\w+)\@/) {
                $individuals{$current_id}{FAMS} ||= [];
                push @{$individuals{$current_id}{FAMS}}, $1;
            }
        } 
        elsif ($current_record eq 'FAM') {
            push @{$families{$current_id}{lines}}, $line;
            
            # Store family relationships
            if ($tag eq 'HUSB' && $value =~ /\@(\w+)\@/) {
                push @{$families{$current_id}{HUSB}}, $1;
            } elsif ($tag eq 'WIFE' && $value =~ /\@(\w+)\@/) {
                push @{$families{$current_id}{WIFE}}, $1;
            } elsif ($tag eq 'CHIL' && $value =~ /\@(\w+)\@/) {
                push @{$families{$current_id}{CHIL}}, $1;
            }
        }
    }
}

# Step 1: Find all the people to be removed (the specified person and all their ancestors)
find_to_remove($remove_person);

# Step 2: Find the root of the tree (assuming it's "I1")
my $root = "I1";

# Step 3: Starting with the root, mark all individuals who are connected 
# and not in the to_remove list as people to keep
mark_connected_to_keep($root);

# Write the filtered GEDCOM to output file
open my $out_fh, '>', $output_file or die "Cannot open output file $output_file: $!";

# Reset tracking variables for output phase
$current_record = '';
$current_id = '';
my $skip_current = 0;

foreach my $line (@lines) {
    chomp $line;
    
    # Skip empty lines
    next if $line =~ /^\s*$/;
    
    # Handle level 0 records (new records)
    if ($line =~ /^0\s+\@(\w+)\@\s+(\w+)/) {
        my $id = $1;
        my $type = $2;
        
        $current_id = $id;
        $current_record = $type;
        
        # Check if this record should be skipped
        if ($type eq 'INDI') {
            $skip_current = !exists $keep_list{$id};
        } elsif ($type eq 'FAM') {
            # Only keep families where at least one member is in the keep list
            $skip_current = 1;
            my $fam = $families{$id};
            
            foreach my $husb (@{$fam->{HUSB}}) {
                if (exists $keep_list{$husb}) {
                    $skip_current = 0;
                    last;
                }
            }
            
            if ($skip_current) {
                foreach my $wife (@{$fam->{WIFE}}) {
                    if (exists $keep_list{$wife}) {
                        $skip_current = 0;
                        last;
                    }
                }
            }
            
            if ($skip_current) {
                foreach my $child (@{$fam->{CHIL}}) {
                    if (exists $keep_list{$child}) {
                        $skip_current = 0;
                        last;
                    }
                }
            }
        } else {
            $skip_current = 0;
        }
    }
    
    # Write the line if it shouldn't be skipped
    print $out_fh "$line\n" unless $skip_current;
}

close $out_fh;
#print "GEDCOM processing complete. Output written to $output_file\n";

# Recursive function to find people to remove (person and all ancestors)
sub find_to_remove {
    my $indi_id = shift;
    
    # Skip if already processed
    return if exists $to_remove{$indi_id};
    
    # Mark individual for removal
    $to_remove{$indi_id} = 1;
    
    # Find parent families
    if (exists $individuals{$indi_id} && exists $individuals{$indi_id}{FAMC}) {
        foreach my $fam_id (@{$individuals{$indi_id}{FAMC}}) {
            # Process parents
            if (exists $families{$fam_id}) {
                # Process fathers
                foreach my $father (@{$families{$fam_id}{HUSB}}) {
                    find_to_remove($father);
                }
                
                # Process mothers
                foreach my $mother (@{$families{$fam_id}{WIFE}}) {
                    find_to_remove($mother);
                }
            }
        }
    }
}

# Recursively mark connected individuals to keep
sub mark_connected_to_keep {
    my $indi_id = shift;
    
    # Skip if already processed or if in the to_remove list
    return if exists $keep_list{$indi_id} || exists $to_remove{$indi_id};
    
    # Mark individual to keep
    $keep_list{$indi_id} = 1;
    
    # Process spouse families to find spouses and children
    if (exists $individuals{$indi_id} && exists $individuals{$indi_id}{FAMS}) {
        foreach my $fam_id (@{$individuals{$indi_id}{FAMS}}) {
            if (exists $families{$fam_id}) {
                # Process all family members
                foreach my $member (
                    @{$families{$fam_id}{HUSB}},
                    @{$families{$fam_id}{WIFE}},
                    @{$families{$fam_id}{CHIL}}
                ) {
                    # Skip if it's the person we're processing or in the to_remove list
                    next if $member eq $indi_id || exists $to_remove{$member};
                    mark_connected_to_keep($member);
                }
            }
        }
    }
    
    # Process parent families to find siblings and parents
    if (exists $individuals{$indi_id} && exists $individuals{$indi_id}{FAMC}) {
        foreach my $fam_id (@{$individuals{$indi_id}{FAMC}}) {
            if (exists $families{$fam_id}) {
                # Process all family members
                foreach my $member (
                    @{$families{$fam_id}{HUSB}},
                    @{$families{$fam_id}{WIFE}},
                    @{$families{$fam_id}{CHIL}}
                ) {
                    # Skip if it's the person we're processing or in the to_remove list
                    next if $member eq $indi_id || exists $to_remove{$member};
                    mark_connected_to_keep($member);
                }
            }
        }
    }
}
