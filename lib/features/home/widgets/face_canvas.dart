import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'antroph_face.dart';

/// Renders a monochrome face bitmap coming from the streaming response.
/// Converts the packed bitmask into a tiny 128x128 image and scales it
/// with nearest-neighbor filtering to keep edges crisp while staying smooth.
class FaceCanvas extends StatefulWidget {
  const FaceCanvas({
    super.key,
    required this.bitmap,
    this.timestampMs,
    this.size = 180,
    this.faceColor = AntrophFace.featureColor,
    this.backgroundColor = const Color(0xFF0D0F10),
    this.showFrame = true,
  });

  final Uint8List? bitmap; // packed bits, MSB-first per byte
  final int? timestampMs;
  final double size;
  final Color faceColor;
  final Color backgroundColor;
  final bool showFrame;

  @override
  State<FaceCanvas> createState() => _FaceCanvasState();
}

class _FaceCanvasState extends State<FaceCanvas> {
  static const int _gridSize = 128;
  ui.Image? _image;
  Uint8List? _lastBitmap;
  int? _lastTs;

  @override
  void initState() {
    super.initState();
    _maybeUpdateImage();
  }

  @override
  void didUpdateWidget(covariant FaceCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeUpdateImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _maybeUpdateImage() {
    final bitmap = widget.bitmap;
    final ts = widget.timestampMs;
    if (bitmap == null || bitmap.isEmpty) {
      if (_image != null) setState(() => _image = null);
      _lastBitmap = null;
      _lastTs = null;
      return;
    }

    final sameContent = _lastBitmap == bitmap || (_lastTs != null && _lastTs == ts);
    if (sameContent && _image != null) return;

    _lastBitmap = bitmap;
    _lastTs = ts;
    _buildImage(bitmap, widget.faceColor);
  }

  void _buildImage(Uint8List packed, Color color) {
    final rgba = Uint8List(_gridSize * _gridSize * 4);
    for (var i = 0; i < _gridSize * _gridSize; i++) {
      final byteIndex = i >> 3;
      if (byteIndex >= packed.length) break;
      final mask = 1 << (7 - (i & 7));
      final on = (packed[byteIndex] & mask) != 0;
      if (on) {
        final pixelIndex = i * 4;
        rgba[pixelIndex + 0] = color.red;
        rgba[pixelIndex + 1] = color.green;
        rgba[pixelIndex + 2] = color.blue;
        rgba[pixelIndex + 3] = color.alpha;
      }
    }

    ui.decodeImageFromPixels(rgba, _gridSize, _gridSize, ui.PixelFormat.rgba8888, (image) {
      if (!mounted) {
        image.dispose();
        return;
      }
      _image?.dispose();
      setState(() => _image = image);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: widget.showFrame ? BoxDecoration(color: widget.backgroundColor) : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: _image != null
            ? RawImage(
                key: ValueKey(_lastTs ?? _image.hashCode),
                image: _image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              )
            : const _FacePlaceholder(),
      ),
    );
  }
}

class _FacePlaceholder extends StatelessWidget {
  const _FacePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.5,
        child: Icon(Icons.face_retouching_natural, color: Colors.white, size: 48),
      ),
    );
  }
}
