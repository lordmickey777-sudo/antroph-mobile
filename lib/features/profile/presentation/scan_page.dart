import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';
import 'package:antroph_mobile/widgets/toast.dart';
import 'package:antroph_mobile/widgets/app_button.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.enableScanner = true});

  /// Useful for widget tests to avoid initializing camera hardware.
  final bool enableScanner;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final MobileScannerController _controller;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 750,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _processing = true;
    HapticFeedback.mediumImpact();
    // Stop the camera to avoid repeated scans
    await _controller.stop();
    if (!mounted) return;
    showToast(context, 'Scanned: $raw', success: true);
    // Return the value to the previous screen if it expects a result
    // ignore: use_build_context_synchronously
    Navigator.of(context).maybePop(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan your Antroph'),
        leading: const BackButton(),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Live camera preview (or placeholder for tests)
                    if (widget.enableScanner)
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        overlayBuilder: (context, constraints) => _ScannerOverlay(),
                      )
                    else
                      Container(
                        color: const Color(0xFF222427),
                        alignment: Alignment.center,
                        child: const TypographyText(
                          'Scanner disabled in test',
                          variant: TypographyVariant.body2,
                          color: Colors.white70,
                        ),
                      ),

                    // Bottom controls
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ControlChip(
                            icon: Icons.flash_on,
                            label: 'Torch',
                            onTap: () => _controller.toggleTorch(),
                          ),
                          _ControlChip(
                            icon: Icons.cameraswitch,
                            label: 'Flip',
                            onTap: () => _controller.switchCamera(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: AppButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2D2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () async {
                  if (!widget.enableScanner) return;
                  // Restart scan if previously stopped after a detection
                  // Restart scanning (start is idempotent for MobileScannerController)
                  await _controller.start();
                  showToast(context, 'Scanning…', success: true);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_scanner),
                    SizedBox(width: 10),
                    Text('Scan QR Code'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final square = size.shortestSide * 0.72;
        final left = (size.width - square) / 2;
        final top = (size.height - square) / 2;
        const borderColor = Colors.white;
        return Stack(
          children: [
            // Darken edges
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                    stops: const [0.60, 1.0],
                  ),
                ),
              ),
            ),
            // Corner borders
            Positioned(
              left: left,
              top: top,
              width: square,
              height: square,
              child: CustomPaint(painter: _CornersPainter(color: borderColor)),
            ),
          ],
        );
      },
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const corner = 28.0;
    const strokeWidth = 4.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(0, 0), Offset(corner, 0), p);
    canvas.drawLine(Offset(0, 0), Offset(0, corner), p);
    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - corner, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, corner), p);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(corner, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - corner), p);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - corner, size.height), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - corner), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            TypographyText(label, variant: TypographyVariant.body2, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
