import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymentResult { success, cancel, unknown }

class PaymentWebView extends StatefulWidget {
  const PaymentWebView({
    super.key,
    required this.initialUrl,
  });

  final String initialUrl;

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _setLoading(true);
            final PaymentResult? result = _resolveResult(url);
            if (result != null) {
              Navigator.of(context).pop(result);
            }
          },
          onPageFinished: (_) => _setLoading(false),
          onNavigationRequest: (NavigationRequest request) {
            final PaymentResult? result = _resolveResult(request.url);
            if (result != null) {
              Navigator.of(context).pop(result);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _setLoading(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = value;
    });
  }

  PaymentResult? _resolveResult(String url) {
    final String normalized = url.toLowerCase();
    if (normalized.contains('/payments/success')) {
      return PaymentResult.success;
    }
    if (normalized.contains('/payments/cancel')) {
      return PaymentResult.cancel;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(PaymentResult.unknown),
        ),
      ),
      body: Column(
        children: <Widget>[
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Stack(
              children: <Widget>[
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x11000000),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
