# Jellyfin 10.11.7 for LoongArch64

Dockerfile to build and run [Jellyfin](https://jellyfin.org/) media server on LoongArch64 (Loongson 3A5000/3A6000 etc.).

## Build

```bash
# With classic web UI (default, official jellyfin-web)
docker build -t jellyfin-loongarch64 .

# With Vue web UI (experimental, jellyfin-vue)
docker build --build-arg WEB_UI=vue -t jellyfin-loongarch64-vue .
```

## Run

```bash
docker run -d \
  --name jellyfin \
  -p 8096:8096 \
  -v jellyfin-config:/config \
  -v jellyfin-cache:/cache \
  -v /path/to/media:/media:ro \
  jellyfin-loongarch64
```

Then open `http://<your-ip>:8096/web/` to access the web UI.

## Web UI Options

| `WEB_UI` value | Frontend | Notes |
|---|---|---|
| `classic` (default) | [jellyfin-web](https://github.com/jellyfin/jellyfin-web) | Official, production-ready |
| `vue` | [jellyfin-vue](https://github.com/jellyfin/jellyfin-vue) | Community rewrite, experimental |

Both frontends are static files extracted from official amd64 Docker images (platform-independent), so no Node.js build is needed on loongarch64.

You can also switch web UI at runtime without rebuilding:

```bash
docker run ... jellyfin-loongarch64 \
  --webdir /opt/jellyfin-web-vue
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8096 | TCP | HTTP web interface |
| 8920 | TCP | HTTPS web interface |
| 1900 | UDP | DLNA discovery |
| 7359 | UDP | Client auto-discovery |

## Notes

- **Base image**: AOSC OS `container-20260312` (provides glibc >= 2.40 needed by .NET on LoongArch)
- **.NET SDK**: 9.0.104 from [loongson-community/dotnet-unofficial-build](https://github.com/loongson-community/dotnet-unofficial-build), verified with SHA-256 checksum
- **Non-root**: Runs as a dedicated `jellyfin` user inside the container
- **SQLite fix**: The `SQLitePCLRaw` NuGet package has no loongarch64 native library, so the system `libsqlite3.so` is symlinked as `libe_sqlite3.so`
- **SkiaSharp fix**: Jellyfin 10.11.7 uses SkiaSharp 3.116.1 which predates loongarch64 support. The native `libSkiaSharp.so` is extracted from SkiaSharp 3.119.0 ([mono/SkiaSharp#3198](https://github.com/mono/SkiaSharp/pull/3198))
- **FFmpeg**: Uses AOSC OS's packaged ffmpeg. For hardware-accelerated transcoding, consider building [jellyfin-ffmpeg](https://github.com/jellyfin/jellyfin-ffmpeg)

## Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `BASE_IMAGE` | `aosc/aosc-os:container-20260312` | Base image |
| `JELLYFIN_VERSION` | `10.11.7` | Jellyfin server version |
| `SKIASHARP_VERSION` | `3.119.0` | SkiaSharp native assets version |
| `WEB_UI` | `classic` | Web UI: `classic` or `vue` |
