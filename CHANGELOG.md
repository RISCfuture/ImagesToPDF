# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-15

### Added

- `images-to-pdf`, a macOS command-line tool that converts a nested directory
  structure of images into a single PDF file with a Table of Contents.
- The Table of Contents mirrors the input directory structure and is written as
  a PDF outline, so it appears in any PDF viewer's Outline feature.
- `--title` to set the Table of Contents title, defaulting to the name of the
  input directory.
- `--size` to set the page size, given either as a name (e.g. `a2`) or as a
  width and height in points (e.g. `1191x1684`), defaulting to letter.
- Originally written for the instrument procedure plates that come with Falcon
  BMS campaign documentation, but usable with any collection of images.

[Unreleased]: https://github.com/RISCfuture/ImagesToPDF/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/RISCfuture/ImagesToPDF/releases/tag/v1.0.0
