ARG BASE_IMAGE=aosc/aosc-os:container-20260312
ARG WEB_CLASSIC_IMAGE=jellyfin/jellyfin:10.11.7
ARG WEB_VUE_IMAGE=jellyfin/jellyfin-vue:unstable

FROM --platform=linux/amd64 ${WEB_CLASSIC_IMAGE} AS web-classic
FROM --platform=linux/amd64 ${WEB_VUE_IMAGE} AS web-vue

FROM ${BASE_IMAGE} AS build

ARG JELLYFIN_VERSION=10.11.7
ARG JELLYFIN_FFMPEG_VERSION=v7.1.3-4
ARG DOTNET_SDK_URL="https://github.com/loongson-community/dotnet-unofficial-build/releases/download/v9.0.201%2Bloong.20250313.build.20250313/dotnet-sdk-9.0.104-linux-loongarch64.tar.gz"
ARG DOTNET_SDK_SHA256="3c29cf43ecb99731450ccbd020a5734545cf707e603c4bcef8586263dd6d0238"
ARG SKIASHARP_VERSION=3.119.0
ARG SKIASHARP_SHA256="cac1d71897ae8b8ba38ba6d2048ce9a8c45f2895ea8ffd3c65dd0c2017901f7b"

# Install build dependencies for Jellyfin server and jellyfin-ffmpeg.
RUN oma install -y \
      curl git tar unzip make gcc pkg-config nasm yasm \
      zlib icu openssl krb5 sqlite \
      gmp gnutls chromaprint opencl-registry-api libcl libdrm libxml2 \
      libass freetype fribidi fontconfig harfbuzz libva \
      libbluray lame opus libtheora libvorbis openmpt \
      dav1d svt-av1 libwebp libvpx x264 x265 zvbi zimg \
      libfdk-aac libplacebo vulkan shaderc

RUN git clone --depth 1 --branch "${JELLYFIN_FFMPEG_VERSION}" \
      https://github.com/jellyfin/jellyfin-ffmpeg.git /src/jellyfin-ffmpeg

WORKDIR /src/jellyfin-ffmpeg
RUN ln -s debian/patches patches \
    && for p in $(cat patches/series); do patch -p1 < "patches/$p"; done

RUN ./configure \
      --prefix=/opt/jellyfin-ffmpeg \
      --target-os=linux \
      --extra-version=Jellyfin \
      --extra-ldflags="-Wl,-rpath,/opt/jellyfin-ffmpeg/lib" \
      --disable-doc \
      --disable-ffplay \
      --disable-static \
      --disable-libxcb \
      --disable-sdl2 \
      --disable-xlib \
      --enable-lto=auto \
      --enable-gpl \
      --enable-version3 \
      --enable-shared \
      --enable-gmp \
      --enable-gnutls \
      --enable-chromaprint \
      --enable-opencl \
      --enable-libdrm \
      --enable-libxml2 \
      --enable-libass \
      --enable-libfreetype \
      --enable-libfribidi \
      --enable-libfontconfig \
      --enable-libharfbuzz \
      --enable-libbluray \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libtheora \
      --enable-libvorbis \
      --enable-libopenmpt \
      --enable-libdav1d \
      --enable-libsvtav1 \
      --enable-libwebp \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libzvbi \
      --enable-libzimg \
      --enable-libfdk-aac \
      --enable-libshaderc \
      --enable-libplacebo \
      --enable-vulkan \
      --enable-vaapi

RUN make -j$(nproc)
RUN make install DESTDIR=/tmp/ffmpeg-install

RUN find /tmp/ffmpeg-install -type f \( -name '*.so*' -o -name 'ffmpeg' -o -name 'ffprobe' \) \
      -exec strip --strip-unneeded {} + \
    && rm -rf /tmp/ffmpeg-install/opt/jellyfin-ffmpeg/include \
              /tmp/ffmpeg-install/opt/jellyfin-ffmpeg/lib/pkgconfig \
              /tmp/ffmpeg-install/opt/jellyfin-ffmpeg/share

RUN mkdir -p /opt/dotnet \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${DOTNET_SDK_URL}" \
    && echo "${DOTNET_SDK_SHA256}  /tmp/dotnet-sdk.tar.gz" | sha256sum -c - \
    && tar xf /tmp/dotnet-sdk.tar.gz -C /opt/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"

RUN git clone --depth 1 --branch "v${JELLYFIN_VERSION}" https://github.com/jellyfin/jellyfin.git /src/jellyfin

WORKDIR /src/jellyfin
RUN dotnet publish Jellyfin.Server \
    --configuration Release \
    --no-self-contained \
    -o /opt/jellyfin

# Fix native library: SQLitePCL has no loongarch64 prebuilt e_sqlite3.so
RUN mkdir -p /opt/jellyfin/runtimes/linux-loongarch64/native \
    && ln -sf /usr/lib/libsqlite3.so /opt/jellyfin/runtimes/linux-loongarch64/native/libe_sqlite3.so

# Fix native library: Jellyfin 10.11.7 ships SkiaSharp 3.116.1 which predates loongarch64 support.
# Extract libSkiaSharp.so from 3.119.0 (added in https://github.com/mono/SkiaSharp/pull/3198).
RUN cd /tmp \
    && curl -fSL -o skiasharp.nupkg \
       "https://www.nuget.org/api/v2/package/SkiaSharp.NativeAssets.Linux/${SKIASHARP_VERSION}" \
    && echo "${SKIASHARP_SHA256}  skiasharp.nupkg" | sha256sum -c - \
    && unzip -o skiasharp.nupkg runtimes/linux-loongarch64/native/libSkiaSharp.so \
    && cp runtimes/linux-loongarch64/native/libSkiaSharp.so \
       /opt/jellyfin/runtimes/linux-loongarch64/native/ \
    && rm -rf /tmp/skiasharp.nupkg /tmp/runtimes

# Extract only the .NET runtime (not full SDK) for the runtime stage
RUN mkdir -p /opt/dotnet-runtime \
    && cp -a /opt/dotnet/dotnet /opt/dotnet-runtime/ \
    && cp -a /opt/dotnet/host /opt/dotnet-runtime/ \
    && cp -a /opt/dotnet/shared /opt/dotnet-runtime/ \
    && cp -a /opt/dotnet/LICENSE.txt /opt/dotnet-runtime/ \
    && cp -a /opt/dotnet/ThirdPartyNotices.txt /opt/dotnet-runtime/

FROM ${BASE_IMAGE}

# WEB_UI: "classic" (default, official jellyfin-web) or "vue" (jellyfin-vue, experimental)
ARG WEB_UI=classic

LABEL org.opencontainers.image.title="Jellyfin" \
      org.opencontainers.image.version="10.11.7" \
      org.opencontainers.image.description="Jellyfin Media Server for LoongArch64 (web UI: ${WEB_UI})" \
      org.opencontainers.image.url="https://jellyfin.org/" \
      org.opencontainers.image.source="https://github.com/darkyzhou/jellyfin-loongarch64"

RUN oma install -y \
      icu openssl krb5 zlib sqlite fontconfig freetype curl \
      gmp gnutls chromaprint libcl libdrm libxml2 libva \
      libass fribidi harfbuzz \
      libbluray lame opus libtheora libvorbis openmpt \
      dav1d svt-av1 libwebp libvpx x264 x265 zvbi zimg \
      libfdk-aac libplacebo vulkan shaderc \
    && oma clean

WORKDIR /opt/jellyfin

COPY --link --from=build /opt/dotnet-runtime /opt/dotnet
COPY --link --from=build /opt/jellyfin /opt/jellyfin
COPY --link --from=build /tmp/ffmpeg-install/opt/jellyfin-ffmpeg /opt/jellyfin-ffmpeg
COPY --link --from=web-classic /jellyfin/jellyfin-web /opt/jellyfin-web-classic
COPY --link --from=web-vue /usr/share/nginx/html /opt/jellyfin-web-vue

RUN ln -sf /opt/jellyfin-web-${WEB_UI} /opt/jellyfin-web

RUN mkdir -p /opt/jellyfin/runtimes/linux-loongarch64/native \
    && ln -sf /usr/lib/libsqlite3.so /opt/jellyfin/runtimes/linux-loongarch64/native/libe_sqlite3.so

# Verify no shared libraries are missing at runtime
RUN ldd /opt/jellyfin-ffmpeg/bin/ffmpeg | grep "not found" && exit 1 || true

RUN useradd -r -s /bin/false jellyfin \
    && mkdir -p /config /cache \
    && chown jellyfin:jellyfin /config /cache

USER jellyfin

ENV DOTNET_ROOT=/opt/dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"

ENV JELLYFIN_DATA_DIR=/config/data
ENV JELLYFIN_CONFIG_DIR=/config
ENV JELLYFIN_CACHE_DIR=/cache
ENV JELLYFIN_LOG_DIR=/config/log
ENV JELLYFIN_WEB_DIR=/opt/jellyfin-web
ENV JELLYFIN_FFMPEG=/opt/jellyfin-ffmpeg/bin/ffmpeg

EXPOSE 8096 8920 1900/udp 7359/udp

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:8096/health || exit 1

ENTRYPOINT ["/opt/dotnet/dotnet", "/opt/jellyfin/jellyfin.dll"]
CMD ["--datadir", "/config/data", \
     "--configdir", "/config", \
     "--cachedir", "/cache", \
     "--logdir", "/config/log", \
     "--ffmpeg", "/opt/jellyfin-ffmpeg/bin/ffmpeg", \
     "--webdir", "/opt/jellyfin-web"]
