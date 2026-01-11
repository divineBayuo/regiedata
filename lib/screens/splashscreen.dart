import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/screens/onboardingscreen.dart';
import 'package:regie_data/screens/Signinpage.dart';
import 'package:regie_data/screens/user_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('first_time') ?? true;
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;

    if (isFirstTime) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // user is logged in, navigate based on role
      navigateBasedOnRole(context);
    } else {
      // no user logged in, navigate to signin page
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  user != null ? const UserHomeScreen() : const Signinpage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );
  }
}
