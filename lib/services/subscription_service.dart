// Conditional import
// dart.library.html - only present on web builds
// dart.library.io   - only present on mobile/desktop builds
// both files export the same function

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: uri_does_not_exist
import 'package:regie_data/services/paystack_webview_mobile.dart'
    if (dart.library.html) 'package:regie_data/services/paystack_webview_web.dart';

// config
// replace with dotenv.env
final _paystackPublicKey = dotenv.env['PAYSTACK_PUBLIC_KEY'] ??
    (throw Exception(
        'PAYSTACK_PUBLIC_KEY not found in .env')); // change form test to live

// prices in GHS pesewas
// Adjust to match dashboard
/* const _planPrices = {
  'pro': 50,
  'business': 100,
}; */

// set billing interval to Monthly and the amount in the smallest currency unit
const _planCodes = {
  'pro': 'PLN_PRO_PLAN_CODE',
  'business': 'PLN_BUSINESS_PLAN_CODE',
};

const _currency = 'GHS'; // or USD

// result from the webview checkout
// the webview returns this after Paystack's callback fires
class PaystackResult {
  final bool success;
  final String? reference; // Paystack transaction reference
  final String?
      subscriptionCode; // Only present when a subscription was created

  const PaystackResult(
      {required this.success, this.reference, this.subscriptionCode});
}

// Service
class SubscriptionService {
  static final _db = FirebaseFirestore.instance;

  // read plan
  // returns the plan as string
  // authoritative source is Firestore, which is updated by the
  // cloud function webhook - not the client directly
  static Future<String> getUserPlan(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['plan'] as String?) ?? 'free';
  }

  // stream that re-emits whenever the plan changes in Firestore
  // because the webhook updates Firestore server-side, this stream
  // will automatically reflect the real subscription state
  static Stream<String> planStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['plan'] as String?) ?? 'free');
  }

  // opens the Paystack checkout with a subscription plan code
  // When the user completes payment, paystack:
  // 1. charges the card immediately for the first month
  // 2. creates a recurring subscription (auto-charge monthly)
  // 3. fires a 'charge.success' webhook to your cloud function
  // The cloud function (not this method) is responsible for:
  // - verifying the webhook signature
  // - updating 'users/{uid}.plan' in Firestore
  // - handling future 'invoice.payment_failed' and 'subscription.disabled' events
  // This method stores the Paystack reference locally so the cloud function
  // can look up which user the webhook belongs to.
  static Future<bool> subscribe({
    required BuildContext context,
    required String targetPlan,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final planCode = _planCodes[targetPlan];
    if (planCode == null) return false;

    // unique reference stored in Firestore so the webhook can find the user
    final reference = 'regie_${user.uid}_${targetPlan}_'
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${Random().nextInt(9999)}';

    // pre-write the pending reference so the webhook handler can match it
    await _db.collection('users').doc(user.uid).update(
        {'pendingPaystackReference': reference, 'pendingPlan': targetPlan});

    // showPaystackCheckout is imported conditionally above
    // correct platform implementation is selected at compile time
    final result = await showPaystackCheckout(
        context: context,
        publicKey: _paystackPublicKey,
        email: user.email ?? '',
        planCode: planCode,  // plan, not one-time payment
        currency: _currency,
        reference: reference,
        metadata: {
          'plan': targetPlan,
          'userId': user.uid,
          'email': user.email ?? ''
        });

    if (result?.success == true) {
      // store the paystacj reference so the webhook can update the plan
      // the plan itself is not updated here - the cloud function does that
      // after verifying the webhook signature
      await _db.collection('users').doc(user.uid).update({
        'paystackReference': result!.reference,
        'paystackSubscriptionCode': result.subscriptionCode,
        'pendingPaystackReference': FieldValue.delete(),
        'pendingPlan': FieldValue.delete(),
      });

      // show a message explaining that activation may take a moment
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Payment received! Your plan will activate within seconds.'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
      }
      return true;
    }

    await _db.collection('users').doc(user.uid).update({
      'pendingPaystackReference': FieldValue.delete(),
      'pendingPlan': FieldValue.delete()
    });
    return false;
  }

  // cancel / downgradae

  // cancels the paystack subscription by calling a cloud function,
  // which calls paystack's 'disable subscription' API
  // the cloud function then fires a 'subscription.disable' webhook
  // which downgrades the plan in Firestore
  // This is intentionally a server-side operation - the client should
  // never directly update the plan field, only the webhook can
  static Future<void> cancelSubscription(String uid) async {
    // trigger the cloud function to cancel via paystack API
    // the cloud function is at: https://<region>-<project>.cloudfunctions.net/cancelSubscription
    // for now we write a cancellation request that the function can process
    await _db.collection('subscription_cancellations').add({
      'userId': uid,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending'
    });
    // the cloud function watches this collection and calls Paystack's
    // disable endpoint, then the resulting webhook downgrades the plan
  }
}
