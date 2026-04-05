# Jellyfin 10.11.7 for LoongArch64
# Build on a loongarch64 machine with: docker build -t jellyfin-loongarch64 .
# Run with: docker run -d -p 8096:8096 -v jellyfin-config:/config -v jellyfin-cache:/cache -v /path/to/media:/media jellyfin-loongarch64

FROM aosc/aosc-os AS build

# Install build dependencies
RUN oma install -y curl git tar zlib icu openssl krb5 sqlite

# Download and install .NET SDK for loongarch64
RUN mkdir -p /opt/dotnet \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz \
       "https://github.com/loongson-community/dotnet-unofficial-build/releases/download/v9.0.201%2Bloong.20250313.build.20250313/dotnet-sdk-9.0.104-linux-loongarch64.tar.gz" \
    && tar xf /tmp/dotnet-sdk.tar.gz -C /opt/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"

# Clone and build Jellyfin
RUN git clone --depth 1 --branch v10.11.7 https://github.com/jellyfin/jellyfin.git /src/jellyfin

WORKDIR /src/jellyfin
RUN dotnet publish Jellyfin.Server \
    --configuration Release \
    --no-self-contained \
    -o /opt/jellyfin

# Fix native library: SQLitePCL has no loongarch64 prebuilt e_sqlite3.so
RUN mkdir -p /opt/jellyfin/runtimes/linux-loongarch64/native \
    && ln -sf /usr/lib/libsqlite3.so /opt/jellyfin/runtimes/linux-loongarch64/native/libe_sqlite3.so

# Fix native library: SkiaSharp 3.116.1 has no loongarch64 prebuilt, grab from 3.119.0
RUN cd /tmp \
    && curl -fSL -o skiasharp.nupkg \
       "https://www.nuget.org/api/v2/package/SkiaSharp.NativeAssets.Linux/3.119.0" \
    && unzip -o skiasharp.nupkg runtimes/linux-loongarch64/native/libSkiaSharp.so \
    && cp runtimes/linux-loongarch64/native/libSkiaSharp.so \
       /opt/jellyfin/runtimes/linux-loongarch64/native/ \
    && rm -rf /tmp/skiasharp.nupkg /tmp/runtimes

# ── Runtime stage ──
FROM aosc/aosc-os

RUN oma install -y icu openssl krb5 zlib sqlite ffmpeg fontconfig freetype

COPY --from=build /opt/dotnet /opt/dotnet
COPY --from=build /opt/jellyfin /opt/jellyfin

# Ensure the sqlite symlink target exists in the runtime image
RUN mkdir -p /opt/jellyfin/runtimes/linux-loongarch64/native \
    && ln -sf /usr/lib/libsqlite3.so /opt/jellyfin/runtimes/linux-loongarch64/native/libe_sqlite3.so

ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"

ENV JELLYFIN_DATA_DIR=/config/data
ENV JELLYFIN_CONFIG_DIR=/config
ENV JELLYFIN_CACHE_DIR=/cache
ENV JELLYFIN_LOG_DIR=/config/log

EXPOSE 8096

VOLUME ["/config", "/cache", "/media"]

ENTRYPOINT ["/opt/dotnet/dotnet", "/opt/jellyfin/jellyfin.dll", \
    "--datadir", "/config/data", \
    "--configdir", "/config", \
    "--cachedir", "/cache", \
    "--logdir", "/config/log", \
    "--ffmpeg", "/usr/bin/ffmpeg", \
    "--nowebclient"]
