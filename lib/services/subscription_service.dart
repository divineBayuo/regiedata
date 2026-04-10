import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _paystackPublicKey = 'pk_live_key_from_dotenv';

// monthly prices in USD cents
// adjusted to fit dashboard
const _planPrices = {
  'pro': 499, // $4.99 to 499 cents
  'business': 999,
} // $9.99 to 999 cents
    ;

const _currency = 'USD';

class SubscriptionService {
  static final _db = FirebaseFirestore.instance;

  // read current plan
  static Future<String> getUserPlan(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['plan'] as String?) ?? 'free';
  }

  static Stream<String> planStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['plan'] as String?) ?? 'free');
  }

  // Initiate payment
  // launches Paystack payment flow for the target plan
  // return true if payment was confirmed and firestore updated
  static Future<bool> subscribe({
    required BuildContext context,
    required String targetPlan,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final amount = _planPrices[targetPlan];
    if (amount == null) return false;

    final email = user.email ?? '';
    // Unique reference - paystack uses this for idempotency
    final reference =
        'regie_${user.uid}_${targetPlan}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PaystackWebView(
          publicKey: _paystackPublicKey,
          email: email,
          amount: amount,
          currency: _currency,
          reference: reference,
          metadata: {'plan': targetPlan, 'userId': user.uid},
        ),
      ),
    );

    if (result == true) {
      await _db.collection('users').doc(user.uid).update({
        'plan': targetPlan,
        'planUpdatedAt': FieldValue.serverTimestamp(),
        'paystackReference': reference,
      });
      return true;
    }
    return false;
  }

  // Downgrade back to free
  static Future<void> cancelSubscription(String uid) async {
    await _db.collection('users').doc(uid).update({
      'plan': 'free',
      'planUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// Webview Checkout Screen

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);

class _PaystackWebView extends StatefulWidget {
  final String publicKey;
  final String email;
  final int amount;
  final String currency;
  final String reference;
  final Map<String, dynamic> metadata;

  const _PaystackWebView({
    required this.publicKey,
    required this.email,
    required this.amount,
    required this.currency,
    required this.reference,
    required this.metadata,
  });

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // - JS to Flutter channel
      // Paystack calls window.paystackcallback.postmessage on events
      ..addJavaScriptChannel(
        'PaystackCallback',
        onMessageReceived: (msg) {
          final raw = msg.message.toLowerCase();
          if (raw.contains('"event":"success"') ||
              raw.contains('"status":"success"')) {
            Navigator.pop(context, true); // paymet succeeded
          } else if (raw.contains('"event":"close"') ||
              raw.contains('"event":"cancel"')) {
            Navigator.pop(context, false); // user closed/cancelled
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (req) {
            // catch any redirect on mobile
            final url = req.url;
            if (url.contains('callback') || url.contains('success')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            if (url.contains('cancel') || url.contains('close')) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  // Build a self-contained html page that initialises
// Paystack inline and auto-opens the payment modal.
// All callbacks auto-opens via the JS channel
  String _buildHtml() {
    final metaJson = widget.metadata.entries
        .map((e) => '"${e.key}": "${e.value}"')
        .join(', ');

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Checkout</title>
  <script src="https://js.paystack.co/v1/inline.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #0A0F0A;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      font-family: -apple-system, sans-serif;
    }
    .card {
      background: #111811;
      border: 1px solid rgba(255,255,255,0.07);
      border-radius: 16px;
      padding: 32px 28px;
      text-align: center;
      max-width: 340px;
      width: 90%;
    }
    .dot {
      width: 48px; height: 48px;
      background: linear-gradient(135deg, #22C55E, #16A34A);
      border-radius: 50%;
      margin: 0 auto 20px;
      display: flex; align-items: center; justify-content: center;
    }
    h2 { color: #fff; font-size: 17px; margin-bottom: 8px; }
    p  { color: rgba(255,255,255,0.4); font-size: 13px; line-height: 1.6; }
    .spinner {
      border: 2px solid rgba(255,255,255,0.1);
      border-top: 2px solid #22C55E;
      border-radius: 50%;
      width: 24px; height: 24px;
      animation: spin 0.8s linear infinite;
      margin: 20px auto 0;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
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
    <h2>Secure Checkout</h2>
    <p>Opening Paystack payment window…</p>
    <div class="spinner"></div>
  </div>

  <script>
    function notify(payload) {
      if (window.PaystackCallback) {
        PaystackCallback.postMessage(JSON.stringify(payload));
      }
    }

    window.onload = function () {
      var handler = PaystackPop.setup({
        key:       '${widget.publicKey}',
        email:     '${widget.email}',
        amount:    ${widget.amount * 100}, // Paystack wants pesewas × 100
        currency:  '${widget.currency}',
        ref:       '${widget.reference}',
        metadata:  { $metaJson },
        onClose: function () {
          notify({ event: 'close' });
        },
        callback: function (response) {
          notify({ event: 'success', reference: response.reference,
                   status: response.status });
        }
      });
      handler.openIframe();
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text('Secure Payment',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
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
                    Text('Loading secure checkout...',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
