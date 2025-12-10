import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/face_state.dart';

class AntrophFace extends StatefulWidget {
  const AntrophFace({
    super.key,
    this.faceDNA = FaceState.neutralDna,
    this.color = Colors.white,
    this.backgroundColor = const Color(0xFF0D0F10),
  });

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
              blinkOpenAmount: _blinkOpenAmount,
              gazeOffset: _gazeOffset,
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
    required this.blinkOpenAmount,
    required this.gazeOffset,
  });

  final FaceState state;
  final Color color;
  final double blinkOpenAmount;
  final Offset gazeOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = min(size.width, size.height) / 140.0;

    const eyeYOffset = -10.0;
    const eyeSpacing = 30.0;

    final currentEyeHeight = state.eyeHeight * blinkOpenAmount;
    final blinkYAdjustment = (state.eyeHeight - currentEyeHeight) / 2;

    _drawEye(
      canvas,
      paint,
      cx - (eyeSpacing + state.eyeWidth / 2) * scale + gazeOffset.dx,
      cy +
          (eyeYOffset - state.eyeHeight / 2) * scale +
          gazeOffset.dy +
          blinkYAdjustment,
      state.eyeWidth * scale,
      currentEyeHeight * scale,
      state.eyeCornerRadius * scale,
      state.eyeAngle == 1,
    );

    _drawEye(
      canvas,
      paint,
      cx + (eyeSpacing - state.eyeWidth / 2) * scale + gazeOffset.dx,
      cy +
          (eyeYOffset - state.eyeHeight / 2) * scale +
          gazeOffset.dy +
          blinkYAdjustment,
      state.eyeWidth * scale,
      currentEyeHeight * scale,
      state.eyeCornerRadius * scale,
      state.eyeAngle == 1,
    );

    final mouthY = cy + 25.0 * scale;

    if (state.mouthType == 0) {
      final mouthPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * scale
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCenter(
        center: Offset(
          cx,
          state.mouthHeight > 0
              ? mouthY
              : mouthY + state.mouthHeight.abs() * scale,
        ),
        width: state.mouthWidth * scale,
        height: state.mouthHeight.abs() * scale,
      );

      if (state.mouthHeight > 0) {
        canvas.drawArc(rect, 0, pi, false, mouthPaint);
      } else {
        canvas.drawArc(rect, pi, pi, false, mouthPaint);
      }
    } else {
      final rect = Rect.fromCenter(
        center: Offset(cx, mouthY),
        width: state.mouthWidth * scale,
        height: state.mouthHeight.abs() * scale,
      );

      if (state.mouthHeight > 0) {
        canvas.drawArc(rect, 0, pi, true, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(5 * scale)),
          paint,
        );
      }
    }
  }

  void _drawEye(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double w,
    double h,
    double r,
    bool isAngry,
  ) {
    if (h < 2) h = 2; // Prevent disappearance

    if (isAngry) {
      final path = Path()
        ..moveTo(x, y + h)
        ..lineTo(x + w, y)
        ..lineTo(x + w, y + h)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}
