# Remuxer FFmpeg Runtime

This folder is copied into `Remuxer.app/Contents/Resources/FFmpeg`.

The bundled `ffmpeg` and `ffprobe` binaries were built from FFmpeg 8.1.1 source:

https://ffmpeg.org/releases/ffmpeg-8.1.1.tar.xz

Build configuration:

```text
./configure --prefix=/private/tmp/remuxer-ffmpeg-install --disable-doc --disable-ffplay --disable-debug --disable-network --enable-videotoolbox --enable-audiotoolbox --enable-securetransport
```

The build reports `License: LGPL version 2.1 or later`.
