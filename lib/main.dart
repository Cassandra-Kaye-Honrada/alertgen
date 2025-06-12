import 'package:allergen/firebase_options.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AlertGen());
}

class AlertGen extends StatelessWidget {
  const AlertGen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: SplashScreen());
  }
}
