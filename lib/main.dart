import 'package:allergen/firebase_options.dart';
import 'package:allergen/screens/authwrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// Global navigator key for accessing navigation context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await EmergencyService().initialize();
  runApp(const AlertGen());
}

class AlertGen extends StatelessWidget {
  const AlertGen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: AuthWrapper(),
    );
  }
}
