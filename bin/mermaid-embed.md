# mermaid-embed(1)

## NAME

**mermaid-embed** - Embed mermaid diagram PNGs into markdown while preserving source

## SYNOPSIS

```
mermaid-embed [OPTIONS] FILE
```

## DESCRIPTION

`mermaid-embed` is a utility that processes markdown files containing mermaid diagrams. It runs the mermaid-cli (`mmdc`) to generate PNG images from mermaid code blocks, then automatically inserts image references into the markdown file while preserving the original mermaid source code.

This allows readers to view rendered diagrams (in GitHub, VS Code preview, etc.) while keeping the source available for future editing.

The script intelligently extracts heading text from above each mermaid block to use as descriptive alt text for the generated images, improving accessibility and SEO.

## OPTIONS

**-h, --help**
: Display help message and exit

**-d, --dry-run**
: Preview what changes would be made without modifying any files. Shows which images would be generated and where references would be inserted.

**-n, --no-backup**
: Skip creating a backup file. Use with caution - the original file will be modified directly without a safety copy.

**-o, --output DIR**
: Specify a custom output directory for generated PNG files. By default, images are placed in the same directory as the input file.

## EXAMPLES

**Basic usage:**
```bash
mermaid-embed architecture.md
```
Processes `architecture.md`, creates backup, generates PNGs, and embeds image references.

**Preview changes:**
```bash
mermaid-embed --dry-run README.md
```
Shows what would happen without making any changes.

**Skip backup (careful!):**
```bash
mermaid-embed --no-backup docs/diagrams.md
```
Modifies file directly without creating a backup.

**Custom output directory:**
```bash
mermaid-embed -o ./images diagrams.md
```
Places generated PNG files in `./images/` directory.

**View help:**
```bash
mermaid-embed --help
```

## BEHAVIOR

### Backup Creation

By default, before modifying the input file, a timestamped backup is created:

```
{filename}.backup.{YYYY-MM-DD-HHMMSS}
```

Example: `README.md.backup.20251111-143045`

### Image Naming

Generated images follow the mermaid-cli convention:

```
{basename}-{N}.png
```

Where `{basename}` is the input filename and `{N}` is the sequential number (1, 2, 3...).

Example for `architecture.md`:
- `architecture.md-1.png`
- `architecture.md-2.png`
- etc.

### Heading Extraction

For each mermaid block, the script searches backwards to find the nearest markdown heading (##, ###, ####, etc.) and uses that text as the image alt text.

**Example:**
```markdown
### System Architecture

```mermaid
graph TD
    A --> B
```
```

Becomes:
```markdown
### System Architecture

![System Architecture](./architecture.md-1.png)

```mermaid
graph TD
    A --> B
```
```

If no heading is found, falls back to generic "Diagram" alt text.

### Mermaid Source Preservation

The original mermaid code blocks remain in the file unchanged. This allows:
- Future editing of diagrams
- Version control of diagram source
- Rendering in environments that support mermaid
- Dual presentation: images for static viewing, source for editing

## FILES

**Input:**
- Markdown file containing mermaid code blocks

**Generated:**
- `{filename}.backup.{timestamp}` - Timestamped backup (unless --no-backup)
- `{basename}-{N}.png` - Generated diagram images

**Modified:**
- Original input file with image references inserted

## DEPENDENCIES

### Required

**mermaid-cli (mmdc)**
```bash
npm install -g @mermaid-js/mermaid-cli
```

Verify installation:
```bash
mmdc --version
```

### Optional

**Puppeteer/Chromium** (required by mermaid-cli)

The mermaid-cli tool uses Puppeteer to render diagrams, which downloads Chromium automatically on first run.

## EXIT STATUS

**0** - Success

**1** - Error occurred:
- mmdc not installed
- Input file not found
- mmdc execution failed
- File write error

## ENVIRONMENT

The script uses Node.js built-in modules only:
- `fs` - File system operations
- `path` - Path manipulation
- `child_process` - Execute mmdc command

No external npm dependencies required.

## NOTES

### Performance

Processing time depends on:
- Number of mermaid diagrams
- Complexity of diagrams
- System resources (Puppeteer/Chromium rendering)

Expect ~1-2 seconds per diagram.

### Image Updates

When diagrams change:
1. Edit the mermaid code in markdown
2. Re-run `mermaid-embed` to regenerate PNGs
3. Existing image references remain correct

### Version Control

Both the markdown and PNG files should be committed:
- **Markdown:** Contains source code and image references
- **PNGs:** Provides rendered output for viewing

Add to `.gitignore` if you want to regenerate images in CI/CD:
```
*.md-*.png
```

### Parallel Processing

The script processes files sequentially. For batch processing:
```bash
for file in docs/*.md; do
    mermaid-embed "$file"
done
```

## TROUBLESHOOTING

**"mmdc not found"**
: Install mermaid-cli: `npm install -g @mermaid-js/mermaid-cli`

**"Puppeteer download failed"**
: Check internet connection and firewall settings
: Try: `npm install -g @mermaid-js/mermaid-cli --unsafe-perm`

**Images not rendering in GitHub**
: Ensure image paths are relative (starting with `./`)
: Check that PNG files are committed to repository

**Wrong image numbers after editing**
: Mermaid blocks are numbered sequentially (1, 2, 3...)
: Adding/removing blocks changes numbering
: Re-run script to regenerate with correct numbers

**Permission denied**
: Ensure script is executable: `chmod +x mermaid-embed`
: Check that `~/Work/dotfiles/bin` is in your PATH

## SEE ALSO

**mermaid-cli documentation:**
- https://github.com/mermaid-js/mermaid-cli

**Mermaid syntax:**
- https://mermaid.js.org/

**Related tools:**
- `mmdc(1)` - Mermaid command-line interface

## AUTHOR

Created for Netflix Delivery Engineering documentation workflows.

## COPYRIGHT

Copyright 2025. This is free software; you are free to change and redistribute it.

## VERSION

mermaid-embed version 1.0.0
