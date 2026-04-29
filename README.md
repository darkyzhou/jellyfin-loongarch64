# Jellyfin for LoongArch64

[Jellyfin](https://jellyfin.org/) media server for LoongArch64 (Loongson 3A5000/3A6000 etc.). Requires Docker on a New-World LoongArch64 Linux host.

## Quick Start

A prebuilt image is available on [Docker Hub](https://hub.docker.com/r/darkyzhou/jellyfin-loongarch64), just pull and run:

```bash
docker run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v jellyfin-config:/config \
  -v jellyfin-cache:/cache \
  -v /path/to/media:/media:ro \
  darkyzhou/jellyfin-loongarch64
```

Then open `http://<your-ip>:8096/web/` to complete the initial setup wizard. Add `/media` as a library path in the wizard.

> **Important**: Replace `/path/to/media` with your actual media directory. Multiple directories can be mounted, e.g. `-v /movies:/media/movies:ro -v /music:/media/music:ro`.

Your config and library data are stored in Docker volumes (`jellyfin-config`, `jellyfin-cache`) and will survive container restarts. Use `docker volume inspect jellyfin-config` to find the path on disk.

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8096 | TCP | HTTP web interface (required) |
| 8920 | TCP | HTTPS (requires certificate setup in Jellyfin settings) |
| 1900 | UDP | DLNA discovery (optional) |
| 7359 | UDP | Client auto-discovery (optional) |

To expose all ports: `-p 8096:8096 -p 8920:8920 -p 1900:1900/udp -p 7359:7359/udp`

## Updating

```bash
docker pull darkyzhou/jellyfin-loongarch64
docker stop jellyfin && docker rm jellyfin
# Re-run the docker run command from Quick Start
```

Your config and library data are preserved in the volumes.

## Web UI Options

| `WEB_UI` value | Frontend | Notes |
|---|---|---|
| `classic` (default) | [jellyfin-web](https://github.com/jellyfin/jellyfin-web) | Official, production-ready |
| `vue` | [jellyfin-vue](https://github.com/jellyfin/jellyfin-vue) | Community rewrite, experimental |

Switch at runtime without rebuilding:

```bash
docker run ... darkyzhou/jellyfin-loongarch64 \
  --webdir /opt/jellyfin-web-vue
```

---

## Build from Source

```bash
# With classic web UI (default)
docker build -t darkyzhou/jellyfin-loongarch64 .

# With Vue web UI
docker build --build-arg WEB_UI=vue -t darkyzhou/jellyfin-loongarch64:vue .
```

### Technical Notes

- **Base image**: AOSC OS (provides glibc >= 2.40 needed by .NET on LoongArch)
- **.NET SDK**: 9.0.104 from [loongson-community/dotnet-unofficial-build](https://github.com/loongson-community/dotnet-unofficial-build), verified with SHA-256 checksum
- **FFmpeg**: Built from [jellyfin/jellyfin-ffmpeg](https://github.com/jellyfin/jellyfin-ffmpeg) 7.1.3 with 94 Jellyfin patches (HDR tone-mapping, VAAPI/Vulkan/OpenCL filters, subtitle overlay, etc.)
- **SQLite fix**: `SQLitePCLRaw` has no loongarch64 native library, `libsqlite3.so` from AOSC OS is symlinked as `libe_sqlite3.so`
- **SkiaSharp fix**: Jellyfin 10.11.8 ships SkiaSharp 3.116.1 (no loongarch64); `libSkiaSharp.so` is extracted from a newer version
- **Non-root**: Runs as a dedicated `jellyfin` user inside the container
