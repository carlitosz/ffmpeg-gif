# `gif`: video to optimized animated GIF

Portable `/bin/sh` command-line script using **FFmpeg** and **gifsicle**. The existing `gif some-video.mp4` workflow stays the same.

## Install

```sh
brew install ffmpeg gifsicle
chmod +x /path/to/repo/gif
# .zshrc: if /path/to/repo/gif is already on PATH, no change needed.
# Or declare: alias gif='/absolute/path/to/repo/gif'
```

## Usage

```sh
gif './screen recording.mp4'                 # saves './screen recording.gif'
gif -d 5 -t 2 './screen recording.mp4'      # start at 2s, 5s total
gif -p quality -o demo.gif video.mov         # preserve detail / smoothness
gif -p small -m 3 video.mp4                 # target <=3 MB
gif -s 400 -f 12 -m 5 video.mp4             # manual maximum width + fps
gif -M 10 video.mp4                         # tighter hard ceiling
gif -h                                      # full options
```

Default **target**: 8 MB. **Hard maximum**: 15 MB (15,000,000 bytes). Existing output files are protected. The script may produce a result between 8 and 15 MB if every tried setting exceeds 8 MB. If none fits within 15 MB, it exits with an error **without publishing an oversized GIF**. It does not silently truncate the input; use `-t/-d` to clip intentionally. Lower-size files are not padded to 1 MB.

## What changed and why

| Area | Previous | New |
|---|---|---|
| Shell | `#!/bin/sh` + nonportable `function`, unquoted paths | Portable POSIX `sh`, quoted paths, early validation |
| FFmpeg executable | `FFMPEG` (not expanded to `$FFMPEG`) | Finds `ffmpeg` / `gifsicle` on `PATH` |
| Palette | Two separate FFmpeg runs with inconsistent filters | Single filtergraph; identical preprocessed frames feed palettegen and paletteuse |
| Scaling | Unconditional width 540 | Never upscales narrower input; scales with Lanczos |
| Sharpening | Very aggressive `unsharp=7:7:2.5` | Disabled: exaggerated edge ringing/noise usually hurts GIF compression |
| Colors | Always default palette | Palette adapts from 256 down to ~64-96 colors |
| Dithering | Implicit default | Stable ordered Bayer with scale 3; often less flicker and smaller output for UI |
| Static backgrounds | Whole-frame dithering | `stats_mode=diff` and `diff_mode=rectangle` help changing regions |
| gifsicle | `-O3` only | `-O3` plus graduated `--lossy` as necessary |
| Files | Fixed Desktop paths, typo in cleanup | Unique temp directory, safe cleanup, output beside input |
| Size | Unbounded | Tries progressively smaller candidates, enforces a hard 15 MB ceiling |

## How to tune quality and size

**Most effective controls (in order for typical screen recordings):**
1. **Duration:** try 3–7 seconds (`-d 5`). GIF is inefficient for long motion clips.
2. **Width:** 300–540 px is useful for embedded UI loops (`-s 400`). Larger area = more pixels per frame.
3. **Frame rate:** 12–18 fps is a good starting point. 18–24 looks smoother but increases size. GIF timing can quantize to centiseconds, so exact frame pacing depends on frame rate/player.
4. **Palette:** 256 for gradients/photographic footage; 96–192 often works for UIs.
5. **Lossy gifsicle:** 15–40 is generally gentle; 60–140 is more aggressive. Inspect text, thin lines and gradients for artifacts.
6. **Dithering:** Bayer tends to make repeated frames compress similarly; `sierra2_4a` can look smoother on natural footage but may increase file size and visual noise. To change, edit `paletteuse=dither=...` in the script.

### Presets and defaults

- `balanced` (default): starts at 540px/18fps, then progressively smaller.
- `quality`: starts at up to 540px/20fps with no lossy gifsicle compression, then downshifts as needed.
- `small`: starts 420px/15fps with more aggressive optimization.

The `-s` and `-f` options **cap** the tiers, not force every attempt to stay at that value. A source narrower than the cap is never enlarged. If the preferred target is reached, the search stops rather than trying to maximize size utilization.

### Operational notes

- Uses private temporary files and removes them on exit/interruption.
- File size is expressed as decimal MB (1 MB = 1,000,000 bytes).
- Outputs animated, infinitely looping GIFs, without audio.
- For source videos with transparency, different scaling and palette settings may be needed; this script targets ordinary opaque screen recordings and videos.
- The best size is not automatically the best perceived quality; always visually inspect the resulting GIF.
- This pipeline does not guarantee that every file will fit. When the ceiling cannot be met, make a shorter clip or manually lower the cap/maximum dimensions.
- If the destination directory is on another filesystem, a safe no-clobber copy is used instead of a hard link.

## References

- [FFmpeg filter documentation](https://ffmpeg.org/ffmpeg-filters.html) — `palettegen`, `paletteuse`, scaling.
- [gifsicle manual](https://github.com/kohler/gifsicle/blob/master/gifsicle.1) — `-O3`, `--lossy`.
