import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/helper_functions/role_navigation.dart';
import 'package:regie_data/screens/onboardingscreen.dart';
import 'package:regie_data/screens/Signinpage.dart';
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
    await Future.delayed(const Duration(seconds: 3));

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
          context, MaterialPageRoute(builder: (_) => const Signinpage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0d8c01),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                'assets/images/regie_splash.png',
                width: 90,
                height: 90,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Regie Data',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Attendance & Data Management',
              style: TextStyle(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white)
          ],
        ),
      ),
    );
  }
}
