import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'dart:html' as html;

const _bg = Color(0xFF0A0F0A);
const _green = Color(0xFF22C55E);
// const _greenDark = Color(0xFF16A34A);

// shows the paystack payment iframe on web using HtmlElementView
// Returns true if payment succeeded, false if cancelled or closed
Future<bool?> showPaystackCheckout({
  required BuildContext context,
  required String publicKey,
  required String email,
  required int amount,
  required String currency,
  required String reference,
  required Map<String, dynamic> metadata,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WebPaystackDialog(
      publicKey: publicKey,
      email: email,
      amount: amount,
      currency: currency,
      reference: reference,
      metadata: metadata,
    ),
  );
}

class _WebPaystackDialog extends StatefulWidget {
  final String publicKey;
  final String email;
  final int amount;
  final String currency;
  final String reference;
  final Map<String, dynamic> metadata;

  const _WebPaystackDialog({
    required this.publicKey,
    required this.email,
    required this.amount,
    required this.currency,
    required this.reference,
    required this.metadata,
  });

  @override
  State<_WebPaystackDialog> createState() => __WebPaystackDialogState();
}

class __WebPaystackDialogState extends State<_WebPaystackDialog> {
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    // Use reference as unique view type to avoid dialog clash
    _viewType = 'paystack-iframe-${widget.reference}';
    _registerIframe();
  }

  void _registerIframe() {
    // Listen for postMessage from the iframe before registering it
    html.window.onMessage.listen((event) {
      if (!mounted) return;
      final data = event.data;
      if (data is String) {
        final lower = data.toLowerCase();
        if (lower.contains('"event":"success"') ||
            lower.contains('"status":"success"')) {
          Navigator.of(context).pop(true);
        } else if (lower.contains('"event":"close"') ||
            lower.contains('"event":"cancel"')) {
          Navigator.of(context).pop(false);
        }
      }
    });

    // Register the iframe factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..srcdoc = _buildHtml()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '#0A0F0A';
        return iframe;
      },
    );

    setState(() => _registered = true);
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
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <script src="https://js.paystack.co/v1/inline.js"></script>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:#0A0F0A;display:flex;align-items:center;
         justify-content:center;min-height:100vh;font-family:-apple-system,sans-serif}
    .card{background:#111811;border:1px solid rgba(255,255,255,.07);
          border-radius:16px;padding:32px 28px;text-align:center;max-width:340px;width:90%}
    h2{color:#fff;font-size:17px;margin-bottom:8px}
    p{color:rgba(255,255,255,.4);font-size:13px;line-height:1.6}
    .spinner{border:2px solid rgba(255,255,255,.1);border-top:2px solid #22C55E;
             border-radius:50%;width:24px;height:24px;
             animation:spin .8s linear infinite;margin:20px auto 0}
    @keyframes spin{to{transform:rotate(360deg)}}
  </style>
</head>
<body>
  <div class="card">
    <h2>Secure Checkout</h2>
    <p>Opening Paystack payment window…</p>
    <div class="spinner"></div>
  </div>
  <script>
    // On web, use window.parent.postMessage so Flutter can receive it
    function notify(p){ window.parent.postMessage(JSON.stringify(p), '*'); }
    window.onload=function(){
      var h=PaystackPop.setup({
        key:'${widget.publicKey}',
        email:'${widget.email}',
        amount:${widget.amount * 100},
        currency:'${widget.currency}',
        ref:'${widget.reference}',
        metadata:{$metaJson},
        onClose:function(){ notify({event:'close'}); },
        callback:function(r){ notify({event:'success',reference:r.reference,status:r.status}); }
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
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      backgroundColor: _bg,
      child: SizedBox(
        width: (size.width * 0.95).clamp(0, 500),
        height: (size.height * 0.88).clamp(0, 700),
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bg,
                border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white.withOpacity(0.6), size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text('Secure Payment',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: _green, size: 14),
                      const SizedBox(width: 4),
                      Text('Secured by Paystack',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11)),
                    ],
                  )
                ],
              ),
            ),
            // Iframe
            Expanded(
                child: _registered
                    ? HtmlElementView(viewType: _viewType)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF111811),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _green.withOpacity(0.2), width: 1.5),
                              ),
                              child: const Icon(Icons.lock_outline_rounded,
                                  color: _green, size: 24),
                            ),
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(
                                color: _green, strokeWidth: 2),
                            const SizedBox(height: 12),
                            Text('Loading...',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13)),
                          ],
                        ),
                      ))
          ],
        ),
      ),
    );
  }
}
