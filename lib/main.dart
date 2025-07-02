import 'package:allergen/firebase_options.dart';
import 'package:allergen/screens/homescreen.dart';
import 'package:allergen/screens/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return Homescreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.android, size: 80, color: Color(0xFF00A19C)),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Color(0xFF00A19C),
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}



