import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';
import 'package:antroph_mobile/features/hardware/data/waitlist_repository.dart';
import 'package:antroph_mobile/widgets/app_input.dart';
import 'package:antroph_mobile/widgets/app_action_button.dart';

/// Shows the waitlist bottom sheet.
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

class _WaitlistSheetState extends State<_WaitlistSheet> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _SheetState _state = _SheetState.idle;
  String _errorMsg = '';

  @override
  void dispose() {
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
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            if (_state == _SheetState.success)
              _buildSuccess(context)
            else
              _buildForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: context.tertiaryTextColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SvgPicture.asset(
            'assets/icons/hardware.svg',
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(
              context.primaryTextColor,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _state == _SheetState.success ? 'You\'re in!' : 'Join the Waitlist',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.primaryTextColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _state == _SheetState.success
                ? 'We\'ll notify you when our robots are ready.'
                : 'Be the first to know when we launch.',
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(
              controller: _emailCtrl,
              hint: 'Email address',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              readOnly: _state == _SheetState.loading,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _nameCtrl,
              hint: 'Name (optional)',
              icon: Icons.person_outline,
              readOnly: _state == _SheetState.loading,
            ),
            if (_state == _SheetState.error) ...[
              const SizedBox(height: 12),
              Text(
                _errorMsg,
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppPillButton(
                label: _state == _SheetState.loading
                    ? 'Joining...'
                    : 'Join Waitlist',
                onPressed: _state == _SheetState.loading ? null : _submit,
                isLoading: _state == _SheetState.loading,
                icon: _state == _SheetState.loading
                    ? null
                    : Icons.arrow_forward_rounded,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.actionButtonBackground,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: context.actionButtonForeground,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'We\'ll be in touch soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
