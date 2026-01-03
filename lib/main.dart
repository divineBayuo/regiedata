import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/screens/splashscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: const FirebaseOptions(
    apiKey: "AIzaSyCiLkb71aJXWPyiOWwWni0qrZHaa40nHcI",
    authDomain: "regie-4c78a.firebaseapp.com",
    projectId: "regie-4c78a",
    storageBucket: "regie-4c78a.firebasestorage.app",
    messagingSenderId: "674155089068",
    appId: "1:674155089068:web:b9e7615c2228e675e1a309",
    measurementId: "G-KT8ZCZZ0X0",
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Splashscreen(),
    );
  }
}
