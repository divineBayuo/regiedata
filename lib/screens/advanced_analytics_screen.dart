import 'package:flutter/material.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

// Advanced Analytics Screen
// Shown as a full screen from admin dashboard
// All 6 sections are gated - free users see locked preview

class AdvancedAnalyticsScreen extends StatefulWidget {
  const AdvancedAnalyticsScreen({super.key});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  bool _isLoading = true;
  String _userPlan = 'free';
  
  // -- data ---
  

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}