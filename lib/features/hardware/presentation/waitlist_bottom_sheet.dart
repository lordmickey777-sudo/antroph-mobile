import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:antroph_mobile/features/hardware/data/waitlist_repository.dart';

/// Colors for the robotic theme
const _kCyan = Color(0xFF3AD0FF);
const _kDarkBg = Color(0xFF0D1117);
const _kDarkSurface = Color(0xFF161B22);
const _kGreen = Color(0xFF00FF88);
const _kDimText = Color(0xFF8B949E);

/// Shows the robotic-themed waitlist bottom sheet.
Future<void> showWaitlistSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WaitlistSheet(),
  );
}

class _WaitlistSheet extends StatefulWidget {
  const _WaitlistSheet();

  @override
  State<_WaitlistSheet> createState() => _WaitlistSheetState();
}

enum _SheetState { idle, loading, success, error }

class _WaitlistSheetState extends State<_WaitlistSheet>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _SheetState _state = _SheetState.idle;
  String _errorMsg = '';

  late final AnimationController _scanCtrl;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _scanAnim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _state = _SheetState.loading);
    HapticFeedback.lightImpact();

    try {
      await WaitlistRepository.I.joinWaitlist(
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _state = _SheetState.success);
      // Auto-dismiss after 2.5 seconds
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) Navigator.of(context).pop();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = 'Connection failed. Please try again.';
      if (data is Map && data.containsKey('detail')) {
        msg = data['detail'].toString();
      } else if (e.response?.statusCode == 429) {
        msg = 'Too many requests. Please try again later.';
      }
      setState(() {
        _state = _SheetState.error;
        _errorMsg = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _SheetState.error;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        decoration: const BoxDecoration(
          color: _kDarkBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: _kCyan, width: 1),
            left: BorderSide(color: _kCyan, width: 1),
            right: BorderSide(color: _kCyan, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x403AD0FF),
              blurRadius: 30,
              spreadRadius: -5,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_state == _SheetState.success)
              _buildSuccess()
            else
              _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _scanAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            gradient: LinearGradient(
              begin: Alignment(_scanAnim.value, 0),
              end: Alignment(_scanAnim.value + 0.5, 0),
              colors: const [
                Colors.transparent,
                Color(0x0D3AD0FF),
                Colors.transparent,
              ],
            ),
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _kCyan.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Corner bracket decoration + icon
          Row(
            children: [
              // Left corner bracket
              _CornerBracket(color: _kCyan),
              const SizedBox(width: 12),
              Icon(
                Icons.smart_toy_outlined,
                color: _kCyan,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _state == _SheetState.success
                      ? 'PROTOCOL COMPLETE'
                      : 'INITIATING PROTOCOL...',
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kCyan,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              // Right corner bracket
              _CornerBracket(color: _kCyan, flipH: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _state == _SheetState.success
                ? 'You have been registered successfully.'
                : 'Join the waitlist to be first in line.',
            style: const TextStyle(
              fontSize: 14,
              color: _kDimText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Email input
            _RoboticInput(
              controller: _emailCtrl,
              hint: 'Email address',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              enabled: _state != _SheetState.loading,
            ),
            const SizedBox(height: 12),
            // Name input (optional)
            _RoboticInput(
              controller: _nameCtrl,
              hint: 'Name (optional)',
              icon: Icons.person_outline,
              enabled: _state != _SheetState.loading,
            ),
            // Error message
            if (_state == _SheetState.error) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMsg,
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _RoboticButton(
                onPressed: _state == _SheetState.loading ? null : _submit,
                isLoading: _state == _SheetState.loading,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen.withValues(alpha: 0.15),
                border: Border.all(color: _kGreen, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _kGreen.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _kGreen,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'YOU\'RE ON THE LIST',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kGreen,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'We\'ll notify you when our robots\nare ready to ship.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _kDimText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// A styled text input matching the robotic theme.
class _RoboticInput extends StatelessWidget {
  const _RoboticInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _kDimText.withValues(alpha: 0.6), fontSize: 15),
        prefixIcon: Icon(icon, color: _kCyan.withValues(alpha: 0.7), size: 20),
        filled: true,
        fillColor: _kDarkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kCyan.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kCyan.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kCyan.withValues(alpha: 0.1)),
        ),
        errorStyle: TextStyle(color: Colors.red[300], fontSize: 12),
      ),
    );
  }
}

/// The glowing cyan submit button.
class _RoboticButton extends StatelessWidget {
  const _RoboticButton({required this.onPressed, this.isLoading = false});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        splashColor: _kCyan.withValues(alpha: 0.2),
        highlightColor: _kCyan.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: isLoading
                  ? [_kCyan.withValues(alpha: 0.3), _kCyan.withValues(alpha: 0.2)]
                  : [_kCyan, const Color(0xFF2CB5E0)],
            ),
            boxShadow: isLoading
                ? []
                : [
                    BoxShadow(
                      color: _kCyan.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PROCESSING...',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'JOIN WAITLIST',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1117),
                    letterSpacing: 2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Small decorative corner bracket used in the header.
class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.color, this.flipH = false});

  final Color color;
  final bool flipH;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flipH,
      child: SizedBox(
        width: 14,
        height: 14,
        child: CustomPaint(painter: _BracketPainter(color: color)),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
