import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:antroph_mobile/core/theme/theme_provider.dart';

import '../../../core/network/error_formatter.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/toast.dart';
import '../../../widgets/typography_text.dart';
import '../../home/models/expression_models.dart';
import '../../home/widgets/expression_widgets.dart';
import '../providers/robot_pairing_provider.dart';

class RobotPairingPageArgs {
  const RobotPairingPageArgs({required this.pairingToken, this.serial});
  final String pairingToken;
  final String? serial;
}

class RobotPairingPage extends ConsumerStatefulWidget {
  const RobotPairingPage({super.key, required this.pairingToken, this.serial});
  final String pairingToken;
  final String? serial;

  @override
  ConsumerState<RobotPairingPage> createState() => _RobotPairingPageState();
}

class _RobotPairingPageState extends ConsumerState<RobotPairingPage> {
  final _nameCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final friendlyName = _nameCtrl.text.trim();
    if (friendlyName.isEmpty) {
      showToast(context, 'Please enter a name for your Antroph');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final repo = ref.read(robotPairingRepositoryProvider);
    try {
      final response = await repo.completePairing(
        pairingToken: widget.pairingToken,
        friendlyName: friendlyName,
      );
      if (!mounted) return;
      final successLabel = response.robot?.friendlyName ?? friendlyName;
      showToast(context, 'Paired $successLabel successfully', success: true);
      context.goNamed('home');
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      showToast(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unable to pair. Please retry.');
      showToast(context, 'Unable to pair. Please retry.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Name your Antroph'),
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExpressionDisplay(
                  expression: RobotExpression.neutral,
                  size: MediaQuery.of(context).size.width * 0.6,
                ),
              ),
              const SizedBox(height: 28),
              TypographyText(
                'What do you want to name your Antroph?',
                variant: TypographyVariant.h2,
                color: Colors.white,
                textAlign: TextAlign.center,
              ),
              if (widget.serial != null && widget.serial!.isNotEmpty) ...[
                const SizedBox(height: 8),
                TypographyText(
                  'Serial ${widget.serial}',
                  variant: TypographyVariant.body2,
                  color: Colors.white60,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              AppInput(
                controller: _nameCtrl,
                hint: 'Friendly name',
                icon: Icons.tag,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.actionButtonBackground,
                    foregroundColor: context.actionButtonForeground,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.actionButtonForeground,
                          ),
                        )
                      : const Text('Complete pairing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
