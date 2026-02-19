import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:antroph_mobile/widgets/shimmer.dart';
import 'package:antroph_mobile/widgets/typography_text.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, this.enableWebView = true});

  /// Disable platform webview in tests to avoid platform view initialization.
  final bool enableWebView;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.enableWebView) {
      _initController();
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://www.antroph.com/support/'));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Support')),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (widget.enableWebView)
              Builder(
                builder: (context) {
                  _controller ??= (() {
                    _initController();
                    return _controller!;
                  })();
                  return WebViewWidget(controller: _controller!);
                },
              )
            else
              const _DisabledPlaceholder(),
            if (_isLoading && widget.enableWebView)
              const Positioned.fill(
                child: ShimmerWebViewPlaceholder(
                  backgroundColor: Color(0xFF1E1F22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisabledPlaceholder extends StatelessWidget {
  const _DisabledPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1F22),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: TypographyText(
          'Support page (webview disabled in test)\nhttps://www.antroph.com/support/',
          variant: TypographyVariant.body2,
          color: Colors.white70,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
