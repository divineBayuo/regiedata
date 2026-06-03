// Mobile implementation — WebViewController
// Compiled on Android and iOS only.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:regie_data/services/subscription_service.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);

/// Shows the Paystack subscription checkout on mobile.
/// Returns a [PaystackResult] with success status, reference, and
/// subscription code if a subscription was created.
Future<PaystackResult?> showPaystackCheckout({
  required BuildContext context,
  required String publicKey,
  required String email,
  required String planCode, // Paystack plan code (PLN_xxx)
  required String currency,
  required String reference,
  required Map<String, dynamic> metadata,
}) {
  return Navigator.push<PaystackResult>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _MobilePaystackScreen(
        publicKey: publicKey,
        email: email,
        planCode: planCode,
        currency: currency,
        reference: reference,
        metadata: metadata,
      ),
    ),
  );
}

class _MobilePaystackScreen extends StatefulWidget {
  final String publicKey;
  final String email;
  final String planCode;
  final String currency;
  final String reference;
  final Map<String, dynamic> metadata;

  const _MobilePaystackScreen({
    required this.publicKey,
    required this.email,
    required this.planCode,
    required this.currency,
    required this.reference,
    required this.metadata,
  });

  @override
  State<_MobilePaystackScreen> createState() => _MobilePaystackScreenState();
}

class _MobilePaystackScreenState extends State<_MobilePaystackScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'PaystackCallback',
          onMessageReceived: (msg) {
            try {
              final data = jsonDecode(msg.message) as Map<String, dynamic>;
              final event = (data['event'] as String? ?? '').toLowerCase();
              final status = (data['status'] as String? ?? '').toLowerCase();

              if (event == 'success' || status == 'success') {
                final result = PaystackResult(
                  success: true,
                  reference: data['reference'] as String?,
                  subscriptionCode: data['subscriptionCode'] as String?,
                );
                if (mounted) Navigator.pop(context, result);
              } else if (event == 'close' || event == 'cancel') {
                if (mounted)
                  Navigator.pop(context, const PaystackResult(success: false));
              }
            } catch (_) {
              // malformed message — ignore
            }
          },
        )
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (e) =>
              debugPrint('WebView error: ${e.description}'),
          onNavigationRequest: (req) {
            final url = req.url.toLowerCase();
            if (url.contains('callback') || url.contains('success')) {
              if (mounted) {
                Navigator.pop(context, const PaystackResult(success: true));
              }
              return NavigationDecision.prevent;
            }
            if (url.contains('cancel') || url.contains('close')) {
              if (mounted) {
                Navigator.pop(context, const PaystackResult(success: false));
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadHtmlString(_buildHtml());
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _buildHtml() {
    final metaJson = widget.metadata.entries
        .map((e) => '"${e.key}": "${e.value}"')
        .join(', ');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <script src="https://js.paystack.co/v1/inline.js"></script>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:#0A0F0A;display:flex;align-items:center;
         justify-content:center;min-height:100vh;font-family:-apple-system,sans-serif}
    .card{background:#111811;border:1px solid rgba(255,255,255,0.07);
          border-radius:16px;padding:32px 28px;text-align:center;max-width:340px;width:90%}
    .dot{width:48px;height:48px;background:linear-gradient(135deg,#22C55E,#16A34A);
         border-radius:50%;margin:0 auto 20px;display:flex;align-items:center;justify-content:center}
    h2{color:#fff;font-size:17px;margin-bottom:8px}
    p{color:rgba(255,255,255,0.4);font-size:13px;line-height:1.6}
    .spinner{border:2px solid rgba(255,255,255,0.1);border-top:2px solid #22C55E;
             border-radius:50%;width:24px;height:24px;
             animation:spin .8s linear infinite;margin:20px auto 0}
    @keyframes spin{to{transform:rotate(360deg)}}
  </style>
</head>
<body>
  <div class="card">
    <div class="dot">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
        <path d="M9 12l2 2 4-4" stroke="#fff" stroke-width="2.5"
              stroke-linecap="round" stroke-linejoin="round"/>
        <circle cx="12" cy="12" r="9" stroke="#fff" stroke-width="2"/>
      </svg>
    </div>
    <h2>Secure Subscription</h2>
    <p>Setting up your monthly plan…</p>
    <div class="spinner"></div>
  </div>
  <script>
    function notify(p){
      if(window.PaystackCallback){
        PaystackCallback.postMessage(JSON.stringify(p));
      }
    }
    window.onload=function(){
      var h=PaystackPop.setup({
        key:'${widget.publicKey}',
        email:'${widget.email}',
        plan:'${widget.planCode}',
        currency:'${widget.currency}',
        ref:'${widget.reference}',
        metadata:{$metaJson},
        onClose:function(){ notify({event:'close'}); },
        callback:function(r){
          notify({
            event:'success',
            reference:r.reference,
            status:r.status,
            subscriptionCode: r.subscription ? r.subscription.subscription_code : null
          });
        }
      });
      h.openIframe();
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _bar(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Payment could not be loaded',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    setState(() => _error = null);
                    _init();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                        color: _green, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _bar(context),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading)
            Container(
              color: _bg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _green.withOpacity(0.2), width: 1.5),
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          color: _green, size: 28),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(
                        color: _green, strokeWidth: 2),
                    const SizedBox(height: 16),
                    Text('Loading secure checkout…',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  AppBar _bar(BuildContext context) => AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text('Subscribe',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () =>
              Navigator.pop(context, const PaystackResult(success: false)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      );
}
