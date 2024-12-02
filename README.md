# ImagesToPDF

Converts a nested directory structure of images to a PDF file with Table of
Contents.

This command-line tool was originally intended to be used with the instrument
procedure plates that come with Falcon BMS campaign documentation, but can
easily be used with any collection of images.

The generated Table of Contents is saved as a PDF outline, and will appear using
any PDF viewer’s Outline feature.

## Requirements and Installation

This tool was built using Swift 6 and requires macOS 14 or newer. Run
`swift build` to build the executable.

## Usage

```
USAGE: images-to-pdf [<input>] <output> [--title <title>] [--size <size>]

ARGUMENTS:
<input>                 The input directory containing the image files.
<output>                The PDF file to generate.

OPTIONS:
-t, --title <title>     The title of the Table of Contents for the generated PDF. (default: file name)
-s, --size <size>       The page size of the resulting PDF. Can be a name (e.g. ‘a2’) or a width and height in points (e.g. ‘1191x1684’). (default: letter)
-h, --help              Show help information.
```
