import 'package:flutter/material.dart';

class Splashscreen extends StatelessWidget {
  const Splashscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f8b02),
      body: Center(
        child: Image.asset(
          'assets/images/regie_splash.png',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}