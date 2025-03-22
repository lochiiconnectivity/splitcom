# SPLITCOM

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Perl utility for splitting GEDCOM genealogy files by removing a specific person and all their ancestry data.

## Overview

SPLITCOM is a command-line tool that processes GEDCOM (GEnealogical Data COMmunication) files and creates a new file with a specific person and all their ancestral connections removed. This can be useful for:

- Privacy protection when sharing family tree data
- Creating subset genealogy files for specific branches
- Removing erroneous genealogical connections
- Preparing GEDCOM files for specialised analysis

## Installation

Clone this repository or download the script:

```bash
git clone https://github.com/lochiiconnectivity/splitcom.git
cd splitcom
```

### Prerequisites

- Perl 5.10 or newer
- Getopt::Long module (included in standard Perl distribution)

## Usage

```bash
perl splitcom.pl -i <input_file> -o <output_file> -p <person_id>
```

### Parameters

- `-i <input_file>`: Path to the input GEDCOM file
- `-o <output_file>`: Path where the modified GEDCOM file will be saved
- `-p <person_id>`: The ID of the person to remove (including all their ancestry)

### Example

```bash
perl splitcom.pl -i family_tree.ged -o modified_tree.ged -p I3
```

This command will read `family_tree.ged`, remove person with ID `@I3@` and all their ancestors, and save the result to `modified_tree.ged`.

## How It Works

1. The script reads the GEDCOM file line by line
2. It identifies the specified person and builds a list of their ancestors
3. During output, it skips records for the specified person and all their ancestors
4. All other relationships and individuals are preserved in the output file
5. Family records are updated to remove references to deleted individuals

## File Format

SPLITCOM works with standard GEDCOM files (versions 5.5 and 5.5.1). The script preserves the header information and other metadata from the original file.

## Limitations

- The tool only removes ancestors, not descendants
- Some GEDCOM tags or custom extensions may not be properly handled
- Very large GEDCOM files may require substantial memory

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
