// Conditional import
// dart.library.html - only present on web builds
// dart.library.io   - only present on mobile/desktop builds
// both files export the same function

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/services/paystack_webview_mobile.dart'
    if (dart.library.html) 'package:regie_data/services/paystack_webview_web.dart';

// config
// replace with dotenv.env
const _paystackPublicKey = 'pk_live_YOUR_HERE';

// prices in GHS pesewas
// Adjust to match dashboard
const _planPrices = {
  'pro': 499,
  'business': 999,
};

const _currency = 'GHS'; // or USD

// Service
class SubscriptionService {
  static final _db = FirebaseFirestore.instance;

  // read plan
  // returns the plan as string
  static Future<String> getUserPlan(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['plan'] as String?) ?? 'free';
  }

  // stream that re-emits whenever the plan changes in Firestore
  static Stream<String> planStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['plan'] as String?) ?? 'free');
  }

  // initiate payment
  // opens the paystack checkout for the chosen target plan
  // on mobile - full-screen webview route
  // on web - dialog with HtmlElementView iframe
  // returns true if payment succeeded and Firestore updated
  static Future<bool> subscribe({
    required BuildContext context,
    required String targetPlan,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final amount = _planPrices[targetPlan];
    if (amount == null) return false;

    final reference = 'regie_${user.uid}_${targetPlan}_'
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${Random().nextInt(9999)}';

    // showPaystackCheckout is imported conditionally above
    // correct platform implementation is selected at compile time
    final result = await showPaystackCheckout(
        context: context,
        publicKey: _paystackPublicKey,
        email: user.email ?? '',
        amount: amount,
        currency: _currency,
        reference: reference,
        metadata: {'plan': targetPlan, 'userId': user.uid});

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

  // cancel / downgradae
  // downgrades to free
  static Future<void> cancelSubscription(String uid) async {
    await _db.collection('users').doc(uid).update({
      'plan': 'free',
      'planUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
