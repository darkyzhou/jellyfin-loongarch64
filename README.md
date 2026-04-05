# Jellyfin 10.11.7 for LoongArch64

Dockerfile to build and run [Jellyfin](https://jellyfin.org/) media server on LoongArch64 (Loongson 3A5000/3A6000 etc.).

## Build

```bash
docker build -t jellyfin-loongarch64 .
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

Then open `http://<your-ip>:8096` to access the setup wizard.

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
- **No web client**: `--nowebclient` is used because jellyfin-web is not bundled. Build [jellyfin-web](https://github.com/jellyfin/jellyfin-web) separately and mount it, or override CMD to point `--webdir` at it
- **FFmpeg**: Uses AOSC OS's packaged ffmpeg. For hardware-accelerated transcoding, consider building [jellyfin-ffmpeg](https://github.com/jellyfin/jellyfin-ffmpeg)

## Customization

Version arguments can be overridden at build time:

```bash
docker build \
  --build-arg JELLYFIN_VERSION=10.11.7 \
  --build-arg SKIASHARP_VERSION=3.119.0 \
  -t jellyfin-loongarch64 .
```

CMD arguments can be overridden at run time:

```bash
docker run -d -p 8096:8096 jellyfin-loongarch64 \
  --datadir /config/data \
  --configdir /config \
  --webdir /path/to/jellyfin-web
```
