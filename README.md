# Jellyfin 10.11.7 for LoongArch64

Dockerfile to build and run [Jellyfin](https://jellyfin.org/) media server on LoongArch64 (Loongson 3A5000/3A6000 etc.).

## Quick Start

A prebuilt image is available on [Docker Hub](https://hub.docker.com/r/darkyzhou/jellyfin-loongarch64) — just pull and run:

```bash
docker run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v jellyfin-config:/config \
  -v jellyfin-cache:/cache \
  -v /path/to/media:/media:ro \
  darkyzhou/jellyfin-loongarch64
```

Then open `http://<your-ip>:8096/web/` to complete the initial setup wizard.

> **Important**: Remember to mount your media directory with `-v /path/to/media:/media:ro`. You can then add `/media` as a library path in the Jellyfin setup wizard. Multiple directories can be mounted, e.g. `-v /movies:/media/movies:ro -v /music:/media/music:ro`.

## Build from Source

If you prefer to build the image yourself:

```bash
# With classic web UI (default, official jellyfin-web)
docker build -t darkyzhou/jellyfin-loongarch64 .

# With Vue web UI (experimental, jellyfin-vue)
docker build --build-arg WEB_UI=vue -t darkyzhou/jellyfin-loongarch64:vue .
```

## Web UI Options

| `WEB_UI` value | Frontend | Notes |
|---|---|---|
| `classic` (default) | [jellyfin-web](https://github.com/jellyfin/jellyfin-web) | Official, production-ready |
| `vue` | [jellyfin-vue](https://github.com/jellyfin/jellyfin-vue) | Community rewrite, experimental |

Both frontends are static files extracted from official amd64 Docker images (platform-independent), so no Node.js build is needed on loongarch64.

You can also switch web UI at runtime without rebuilding:

```bash
docker run ... darkyzhou/jellyfin-loongarch64 \
  --webdir /opt/jellyfin-web-vue
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8096 | TCP | HTTP web interface |
| 8920 | TCP | HTTPS (requires certificate setup in Jellyfin settings) |
| 1900 | UDP | DLNA discovery |
| 7359 | UDP | Client auto-discovery |

## Notes

- **Base image**: AOSC OS `container-20260312` (provides glibc >= 2.40 needed by .NET on LoongArch)
- **.NET SDK**: 9.0.104 from [loongson-community/dotnet-unofficial-build](https://github.com/loongson-community/dotnet-unofficial-build), verified with SHA-256 checksum
- **Non-root**: Runs as a dedicated `jellyfin` user inside the container
- **Volumes**: Not declared via `VOLUME` instruction — use `-v` flags at runtime to mount `/config`, `/cache`, and `/media`
- **SQLite fix**: The `SQLitePCLRaw` NuGet package has no loongarch64 native library, so the system `libsqlite3.so` is symlinked as `libe_sqlite3.so`
- **SkiaSharp fix**: Jellyfin 10.11.7 uses SkiaSharp 3.116.1 which predates loongarch64 support. The native `libSkiaSharp.so` is extracted from SkiaSharp 3.119.0 ([mono/SkiaSharp#3198](https://github.com/mono/SkiaSharp/pull/3198))
- **FFmpeg**: Built from [jellyfin/jellyfin-ffmpeg](https://github.com/jellyfin/jellyfin-ffmpeg) 7.1.3 with 94 Jellyfin patches (HDR tone-mapping, VAAPI/Vulkan/OpenCL filters, subtitle overlay, etc.). Includes chromaprint, fdk-aac, libplacebo, Vulkan, and VAAPI support

## Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `BASE_IMAGE` | `aosc/aosc-os:container-20260312` | Base image |
| `JELLYFIN_VERSION` | `10.11.7` | Jellyfin server version (git tag) |
| `JELLYFIN_FFMPEG_VERSION` | `v7.1.3-4` | jellyfin-ffmpeg version (git tag) |
| `WEB_UI` | `classic` | Web UI: `classic` or `vue` |
| `WEB_CLASSIC_IMAGE` | `jellyfin/jellyfin:10.11.7` | Source image for classic web UI files |
| `WEB_VUE_IMAGE` | `jellyfin/jellyfin-vue:unstable` | Source image for Vue web UI files |
| `SKIASHARP_VERSION` | `3.119.0` | SkiaSharp native assets version |
| `SKIASHARP_SHA256` | `cac1d7...` | SHA-256 checksum for SkiaSharp nupkg |
| `DOTNET_SDK_URL` | [loongson-community release](https://github.com/loongson-community/dotnet-unofficial-build/releases) | .NET SDK tarball URL |
| `DOTNET_SDK_SHA256` | `3c29cf...` | SHA-256 checksum for .NET SDK tarball |
