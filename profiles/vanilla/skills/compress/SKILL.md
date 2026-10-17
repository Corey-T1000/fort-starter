---
name: compress
description: Compress images via CLI or web UI. Use when the user says "compress", "shrink this image", "make this smaller", "optimize this", or needs to reduce image file size.
requires: pngquant + sharp (system deps, install separately)
---

# Compress — Image Compression

> ## Prerequisites
> This skill calls `pngquant` (PNG quantizer) and `sharp` (Node image library). Install before using:
> ```bash
> # macOS
> brew install pngquant
> npm install -g sharp-cli
>
> # Debian/Ubuntu
> sudo apt-get install pngquant
> npm install -g sharp-cli
> ```
> The companion CLI lives at `projects/compress/` — clone or scaffold that project to use the web UI.

Local image compression tool at `projects/compress/`.

## CLI

```bash
compress <file>                        # single file
compress *.png -q 60                   # batch with quality (default 80)
compress hero.jpg logo.png -o ./out    # output to specific dir
```

Output files get `-min` suffix. Originals never overwritten.

## Web UI

```bash
cd "${FORT_ROOT:-$HOME/claudes-fort}/projects/compress" && node server.js
```

Then open `http://localhost:3456`. Drag and drop, quality slider, batch up to 20 files (50MB each).

## Supported Formats

| Format | Engine |
|--------|--------|
| PNG | pngquant + optipng |
| JPEG | Sharp (mozjpeg) |
| WebP | cwebp / Sharp |
| AVIF | Sharp |
| GIF | Sharp (animated) |

## When to Use

- After generating images with `/nano-banana` before committing to a repo
- Before adding OG images or blog assets to `projects/web/`
- Any time file size matters (deploy, email, social)
