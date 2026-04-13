---
name: compress
description: Compress images via CLI or web UI. Use when the user says "compress", "shrink this image", "make this smaller", "optimize this", or needs to reduce image file size.
---

# Compress — Image Compression

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
