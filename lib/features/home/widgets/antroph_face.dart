import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/face_state.dart';

class AntrophFace extends StatefulWidget {
  const AntrophFace({
    super.key,
    this.faceDNA = FaceState.neutralDna,
    this.color = AntrophFace.skinTone,
    this.backgroundColor = const Color(0xFF0D0F10),
  });

  static const Color skinTone = Color(0xFFEBC49D);

  final List<int> faceDNA; // The [7] array from backend
  final Color color;
  final Color backgroundColor;

  @override
  State<AntrophFace> createState() => _AntrophFaceState();
}

class _AntrophFaceState extends State<AntrophFace>
    with TickerProviderStateMixin {
  late FaceState _current;
  late FaceState _target;
  late final AnimationController _morphController;
  late final Animation<double> _morphAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _blinkTimer;
  Timer? _saccadeTimer;
  bool _isBlinking = false;
  double _blinkOpenAmount = 1.0; // 1.0 = open, 0.0 = closed
  Offset _gazeOffset = Offset.zero;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _current = FaceState.fromArray(widget.faceDNA);
    _target = _current;

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    )..addListener(() => setState(() {}));

    _pulseController.repeat(reverse: true);
    _morphController.addListener(() => setState(() {}));

    _startLifeEngine();
  }

  @override
  void didUpdateWidget(covariant AntrophFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.faceDNA, oldWidget.faceDNA)) {
      _current = FaceState.lerp(_current, _target, _morphController.value);
      _target = FaceState.fromArray(widget.faceDNA);
      _morphController.forward(from: 0.0);
    }
  }

  void _startLifeEngine() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_rand.nextInt(40) == 0 && !_isBlinking) {
        _performBlink();
      }
    });

    _saccadeTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (_rand.nextDouble() > 0.7) {
        setState(() {
          _gazeOffset = Offset(
            (_rand.nextDouble() - 0.5) * 20,
            (_rand.nextDouble() - 0.5) * 10,
          );
        });
      } else {
        setState(() {
          _gazeOffset = Offset.zero;
        });
      }
    });
  }

  Future<void> _performBlink() async {
    setState(() => _isBlinking = true);
    for (int i = 0; i < 5; i++) {
      setState(() => _blinkOpenAmount -= 0.2);
      await Future.delayed(const Duration(milliseconds: 15));
    }
    for (int i = 0; i < 5; i++) {
      setState(() => _blinkOpenAmount += 0.2);
      await Future.delayed(const Duration(milliseconds: 15));
    }
    setState(() {
      _isBlinking = false;
      _blinkOpenAmount = 1.0;
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _saccadeTimer?.cancel();
    _morphController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = FaceState.lerp(_current, _target, _morphController.value);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: widget.backgroundColor,
        child: SizedBox.expand(
          child: CustomPaint(
            painter: FacePainter(
              state: state,
              color: widget.color,
              backgroundColor: widget.backgroundColor,
              blinkOpenAmount: _blinkOpenAmount,
              gazeOffset: _gazeOffset,
              pulse: _pulseAnimation.value,
            ),
          ),
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  FacePainter({
    required this.state,
    required this.color,
    required this.backgroundColor,
    required this.blinkOpenAmount,
    required this.gazeOffset,
    required this.pulse,
  });

  final FaceState state;
  final Color color;
  final Color backgroundColor;
  final double blinkOpenAmount;
  final Offset gazeOffset;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final scale = min(size.width, size.height) / 140.0;

    _drawBackdrop(canvas, rect, scale);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final eyeSpacing = 30.0 * scale;
    final eyeYOffset = -12.0 * scale;
    const gazeDampening = 0.42;

    final currentEyeHeight = max(
      2.4 * scale,
      state.eyeHeight * blinkOpenAmount * scale,
    );
    final leftEyeCenter = Offset(
      cx - eyeSpacing + gazeOffset.dx * gazeDampening,
      cy + eyeYOffset + gazeOffset.dy * gazeDampening,
    );
    final rightEyeCenter = Offset(
      cx + eyeSpacing + gazeOffset.dx * gazeDampening,
      cy + eyeYOffset + gazeOffset.dy * gazeDampening,
    );

    _drawEye(
      canvas: canvas,
      center: leftEyeCenter,
      width: state.eyeWidth * scale,
      height: currentEyeHeight,
      radius: state.eyeCornerRadius * scale,
      isAngry: state.eyeAngle == 1,
      isLeft: true,
      scale: scale,
    );

    _drawEye(
      canvas: canvas,
      center: rightEyeCenter,
      width: state.eyeWidth * scale,
      height: currentEyeHeight,
      radius: state.eyeCornerRadius * scale,
      isAngry: state.eyeAngle == 1,
      isLeft: false,
      scale: scale,
    );

    final mouthCenter = Offset(cx, cy + 28.0 * scale + pulse * 2.2 * scale);

    _drawMouth(
      canvas: canvas,
      center: mouthCenter,
      width: state.mouthWidth * scale,
      height: state.mouthHeight * scale,
      mouthType: state.mouthType,
      scale: scale,
    );

    _drawCheeks(canvas, leftEyeCenter, rightEyeCenter, mouthCenter, scale);
  }

  void _drawBackdrop(Canvas canvas, Rect rect, double scale) {
    canvas.drawRect(rect, Paint()..color = backgroundColor);

    final halo = RadialGradient(
      center: const Alignment(0, -0.35),
      radius: 1.25,
      colors: [color.withOpacity(0.22 + pulse * 0.12), backgroundColor],
    );
    canvas.drawRect(rect, Paint()..shader = halo.createShader(rect));

    final frame = RRect.fromRectAndRadius(
      rect.deflate(2.5 * scale),
      Radius.circular(18 * scale),
    );
    final framePaint = Paint()
      ..color = color.withOpacity(0.18 + pulse * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, 10 * scale);
    canvas.drawRRect(frame, framePaint);

    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.06 + pulse * 0.02),
          Colors.white.withOpacity(0),
        ],
        stops: const [0, 0.75],
      ).createShader(rect);
    canvas.drawRect(rect, gloss);

    final bandHeight = 12 * scale;
    final bandRect = Rect.fromLTWH(rect.left, rect.top, rect.width, bandHeight);
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.14 + pulse * 0.08),
          Colors.white.withOpacity(0),
        ],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, bandPaint);

    final bottomGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.9),
        radius: 0.8,
        colors: [color.withOpacity(0.12 + pulse * 0.1), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, bottomGlow);
  }

  void _drawEye({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    required double radius,
    required bool isAngry,
    required bool isLeft,
    required double scale,
  }) {
    final clampedHeight = max(height, 2.4 * scale);
    final corner = Radius.circular(max(radius, 4.0 * scale));
    final eyeRect = Rect.fromCenter(
      center: center,
      width: width,
      height: clampedHeight,
    );
    final eyeShape = RRect.fromRectAndRadius(eyeRect, corner);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.2 + pulse * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale);
    canvas.drawRRect(eyeShape.inflate(3 * scale), glowPaint);

    final eyePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.92), color.withOpacity(0.75)],
      ).createShader(eyeRect);
    canvas.drawRRect(eyeShape, eyePaint);

    final lidHeight = clampedHeight * (isAngry ? 0.75 : 1.0);
    final lidRect = Rect.fromCenter(
      center: center,
      width: width,
      height: lidHeight,
    );
    final lidShape = RRect.fromRectAndRadius(lidRect, corner);
    canvas.drawRRect(
      lidShape,
      Paint()..color = backgroundColor.withOpacity(isAngry ? 0.2 : 0.12),
    );

    final pupilHeight = max(clampedHeight * 0.55, 4.5 * scale);
    final pupilWidth = width * 0.35;
    final pupilRect = Rect.fromCenter(
      center: center.translate(0, -clampedHeight * 0.02),
      width: pupilWidth,
      height: pupilHeight,
    );
    final pupilShape = RRect.fromRectAndRadius(
      pupilRect,
      Radius.circular(corner.x * 0.7),
    );
    final pupilGlowPaint = Paint()
      ..color = color.withOpacity(0.18 + pulse * 0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale);
    canvas.drawRRect(pupilShape.inflate(3 * scale), pupilGlowPaint);
    canvas.drawRRect(
      pupilShape,
      Paint()..color = backgroundColor.withOpacity(0.25),
    );
    canvas.drawRRect(
      pupilShape.inflate(1.4 * scale),
      Paint()
        ..color = color.withOpacity(0.18 + pulse * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * scale,
    );

    canvas.drawCircle(
      Offset(
        pupilRect.left + pupilRect.width * 0.35,
        pupilRect.top + pupilRect.height * 0.32,
      ),
      1.6 * scale,
      Paint()..color = Colors.white.withOpacity(0.82),
    );

    final browTilt = isAngry ? (isLeft ? -1 : 1) * 6 * scale : 0.0;
    final browPaint = Paint()
      ..color = color.withOpacity(isAngry ? 0.9 : 0.5)
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(
        center.dx - width * 0.55,
        center.dy - clampedHeight * (isAngry ? 0.9 : 1.05),
      ),
      Offset(
        center.dx + width * 0.55,
        center.dy - clampedHeight * (isAngry ? 0.9 : 1.05) + browTilt,
      ),
      browPaint,
    );
  }

  void _drawMouth({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    required int mouthType,
    required double scale,
  }) {
    final isSmile = height >= 0;
    final mouthHeight = max(height.abs(), 4.0 * scale);
    final lift = isSmile ? -mouthHeight : mouthHeight;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.16 + pulse * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(3.0 * scale, mouthHeight * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * scale);

    if (mouthType == 0) {
      final start = Offset(center.dx - width / 2, center.dy);
      final end = Offset(center.dx + width / 2, center.dy);
      final control = Offset(center.dx, center.dy + lift * 0.8);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(3.0 * scale, mouthHeight * 0.22)
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final mouthRect = Rect.fromCenter(
        center: Offset(
          center.dx,
          center.dy + (isSmile ? -mouthHeight * 0.1 : mouthHeight * 0.05),
        ),
        width: width,
        height: mouthHeight * (isSmile ? 1.0 : 0.85),
      );
      final shape = RRect.fromRectAndRadius(
        mouthRect,
        Radius.circular(6 * scale),
      );
      canvas.drawRRect(shape.inflate(1.4 * scale), glowPaint);
      canvas.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.95), color.withOpacity(0.75)],
          ).createShader(mouthRect),
      );

      final shineRect = Rect.fromLTWH(
        mouthRect.left + mouthRect.width * 0.12,
        mouthRect.top + mouthRect.height * 0.18,
        mouthRect.width * 0.36,
        mouthRect.height * 0.3,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shineRect, Radius.circular(4 * scale)),
        Paint()..color = Colors.white.withOpacity(0.28),
      );
    }
  }

  void _drawCheeks(
    Canvas canvas,
    Offset leftEye,
    Offset rightEye,
    Offset mouthCenter,
    double scale,
  ) {
    final cheekPaint = Paint()
      ..color = color.withOpacity(0.12 + pulse * 0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale);
    final cheekY = mouthCenter.dy + 6 * scale;
    canvas.drawCircle(Offset(leftEye.dx, cheekY), 9 * scale, cheekPaint);
    canvas.drawCircle(Offset(rightEye.dx, cheekY), 9 * scale, cheekPaint);
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.state.eyeWidth != state.eyeWidth ||
        oldDelegate.state.eyeHeight != state.eyeHeight ||
        oldDelegate.state.eyeCornerRadius != state.eyeCornerRadius ||
        oldDelegate.state.eyeAngle != state.eyeAngle ||
        oldDelegate.state.mouthType != state.mouthType ||
        oldDelegate.state.mouthWidth != state.mouthWidth ||
        oldDelegate.state.mouthHeight != state.mouthHeight ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.blinkOpenAmount != blinkOpenAmount ||
        oldDelegate.gazeOffset != gazeOffset ||
        oldDelegate.pulse != pulse;
  }
}
