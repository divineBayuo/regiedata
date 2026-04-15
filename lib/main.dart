import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:regie_data/firebase_options.dart';
import 'package:regie_data/screens/splashscreen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
//import 'package:regie_data/services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    Logger().e('Error loading .env file: ', error: e);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //SubscriptionService.initWebView();

  // only initialize webview on mobile
  if (!kIsWeb) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Regie Data',
      theme: ThemeData(
          fontFamily: 'Quicksand',
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF0A0F0A),
            elevation: 0,
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              fontFamily: 'Quicksand',
            ),
            iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
          )),
      home: const Splashscreen(),
    );
  }
}
