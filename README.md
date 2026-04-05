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

## Notes

- **Base image**: AOSC OS (provides glibc >= 2.40 needed by .NET on LoongArch)
- **.NET SDK**: 9.0.104 from [loongson-community/dotnet-unofficial-build](https://github.com/loongson-community/dotnet-unofficial-build)
- **SQLite fix**: The `SQLitePCLRaw` NuGet package has no loongarch64 native library, so `libsqlite3.so` from the system is symlinked as `libe_sqlite3.so`
- **SkiaSharp fix**: Jellyfin 10.11.7 uses SkiaSharp 3.116.1 which predates loongarch64 support. The native `libSkiaSharp.so` is extracted from SkiaSharp 3.119.0 (which added loongarch64 in [mono/SkiaSharp#3198](https://github.com/mono/SkiaSharp/pull/3198))
- **No web client**: The `--nowebclient` flag is used because jellyfin-web is not bundled. You can add it by building [jellyfin-web](https://github.com/jellyfin/jellyfin-web) separately
- **FFmpeg**: Uses AOSC OS's packaged ffmpeg (no hardware acceleration). For better transcoding, consider building [jellyfin-ffmpeg](https://github.com/jellyfin/jellyfin-ffmpeg)
