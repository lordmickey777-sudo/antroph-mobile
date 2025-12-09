import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chat_models.dart';

class FaceAvatar extends StatefulWidget {
  const FaceAvatar({super.key, required this.pose, this.size = 200});

  final FacePose pose;
  final double size;

  @override
  State<FaceAvatar> createState() => _FaceAvatarState();
}

class _FaceAvatarState extends State<FaceAvatar> with TickerProviderStateMixin {
  late FacePose _currentPose = widget.pose;
  late FacePose _targetPose = widget.pose;
  late FacePose _fromPose = widget.pose;

  late final AnimationController _lerpController;
  late final AnimationController _blinkController;
  late final AnimationController _talkController;

  Timer? _idleBlinkTimer;
  double _blinkPulse = 0;

  @override
  void initState() {
    super.initState();
    _lerpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(_tickLerp);

    _blinkController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 120),
            reverseDuration: const Duration(milliseconds: 120),
          )
          ..addListener(() {
            final v = _blinkController.value;
            final pulse = v <= 0.5
                ? v * 2
                : (1 - v) * 2; // triangle wave 0->1->0
            setState(() => _blinkPulse = pulse);
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _blinkController.reverse();
            } else if (status == AnimationStatus.dismissed) {
              _blinkPulse = 0;
              _scheduleIdleBlink();
            }
          });

    _talkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => setState(() {}));

    _scheduleIdleBlink();
  }

  @override
  void dispose() {
    _idleBlinkTimer?.cancel();
    _lerpController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FaceAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pose != oldWidget.pose) {
      _updatePose(widget.pose);
    }
  }

  void _updatePose(FacePose next) {
    _fromPose = _currentPose;
    _targetPose = next;
    _lerpController.forward(from: 0);
    _scheduleIdleBlink();
    if (next.mouth.talking && !_talkController.isAnimating) {
      _talkController.repeat();
    } else if (!next.mouth.talking && _talkController.isAnimating) {
      _talkController.stop();
    }
    // Trigger a faster blink if server sends one.
    if (next.eyes.blink > 0.6 && !_blinkController.isAnimating) {
      _blinkController.forward(from: 0);
    }
  }

  void _tickLerp() {
    final eased = Curves.easeOut.transform(_lerpController.value);
    setState(() {
      _currentPose = FacePose.lerp(_fromPose, _targetPose, eased);
    });
  }

  void _scheduleIdleBlink() {
    _idleBlinkTimer?.cancel();
    final delay = Duration(milliseconds: 3000 + math.Random().nextInt(4000));
    _idleBlinkTimer = Timer(delay, () {
      if (!_blinkController.isAnimating) {
        _blinkController.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final talkPulse = _talkController.isAnimating
        ? _triangleWave(_talkController.value)
        : 0.0;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _FacePainter(
            pose: _currentPose,
            blinkPulse: _blinkPulse,
            talkPulse: talkPulse,
          ),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.pose,
    required this.blinkPulse,
    required this.talkPulse,
  });

  final FacePose pose;
  final double blinkPulse;
  final double talkPulse;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF1B1F22), Color(0xFF0F1214)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas.drawRRect(frame, bg);

    final blinkLevel = (pose.eyes.blink + blinkPulse).clamp(0.0, 1.0);
    final mouthOpen = (pose.mouth.open + talkPulse * 0.35).clamp(0.0, 1.0);

    _drawEyes(canvas, size, blinkLevel);
    _drawMouth(canvas, size, mouthOpen);
  }

  void _drawEyes(Canvas canvas, Size size, double blink) {
    final eyePaint = Paint()..color = Colors.white.withOpacity(0.92);
    final pupilPaint = Paint()..color = const Color(0xFF0D0F10);
    final glowPaint = Paint()
      ..color = const Color(0xFF4FD1C5).withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final eyeWidth = size.width * 0.18;
    final eyeHeightBase = size.height * 0.12;
    final eyeHeight = eyeHeightBase * (0.2 + (1 - blink) * 0.8);
    final offsetY = size.height * 0.38;

    final leftCenter = Offset(size.width * 0.35, offsetY);
    final rightCenter = Offset(size.width * 0.65, offsetY);

    final pupilOffset = Offset(
      pose.eyes.x * eyeWidth * 0.35,
      pose.eyes.y * eyeHeightBase * 0.4,
    );

    void drawEye(Offset center) {
      final eyeRect = Rect.fromCenter(
        center: center,
        width: eyeWidth,
        height: eyeHeight,
      );
      final eyeShape = RRect.fromRectAndRadius(
        eyeRect,
        Radius.circular(eyeHeight * 0.6),
      );
      canvas.drawRRect(eyeShape, glowPaint);
      canvas.drawRRect(eyeShape, eyePaint);

      final pupilRadius = math.max(eyeHeight * 0.18, 3.0);
      final pupilCenter = center + pupilOffset;
      canvas.drawCircle(pupilCenter, pupilRadius * 1.7, glowPaint);
      canvas.drawCircle(pupilCenter, pupilRadius, pupilPaint);
    }

    drawEye(leftCenter);
    drawEye(rightCenter);
  }

  void _drawMouth(Canvas canvas, Size size, double open) {
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerY = size.height * 0.65;
    final width = size.width * 0.46;
    final height = size.height * 0.08 + open * size.height * 0.08;
    final smile = pose.mouth.smile.clamp(-1.0, 1.0);
    final smileOffset = smile * size.height * 0.025;

    final left = Offset((size.width - width) / 2, centerY + smileOffset);
    final right = Offset((size.width + width) / 2, centerY + smileOffset);
    final topCtrl = Offset(
      size.width / 2,
      centerY - height * 0.35 + smileOffset,
    );
    final bottomCtrl = Offset(
      size.width / 2,
      centerY + height * 0.9 + smileOffset,
    );

    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(topCtrl.dx, topCtrl.dy, right.dx, right.dy)
      ..quadraticBezierTo(
        bottomCtrl.dx,
        bottomCtrl.dy,
        left.dx,
        left.dy + height,
      )
      ..close();

    canvas.drawPath(path, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return pose != oldDelegate.pose ||
        blinkPulse != oldDelegate.blinkPulse ||
        talkPulse != oldDelegate.talkPulse;
  }
}

double _triangleWave(double t) {
  final value = t % 1.0;
  return value <= 0.5 ? value * 2 : (1 - value) * 2;
}
