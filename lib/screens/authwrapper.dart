import 'package:allergen/screens/homescreen.dart';
import 'package:allergen/screens/login.dart';
import 'package:allergen/screens/onboarding.dart';
import 'package:allergen/screens/verify_google.dart';
import 'package:allergen/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _showSplash = true;
  Widget? _targetScreen;

  StreamSubscription<User?>? _authStateSubscription;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _startSplashAndAuth();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSplashAndAuth() async {
    await Future.wait([_showSplashScreen(), _checkAuthState()]);
  }

  Future<void> _showSplashScreen() async {
    _splashTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });

    await Future.delayed(Duration(seconds: 5));
  }

  Future<void> _checkAuthState() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await _handleLoggedInUser(currentUser);
      } else {
        _authStateSubscription = FirebaseAuth.instance
            .authStateChanges()
            .listen((User? user) async {
              if (!mounted) return; 

              if (user == null) {
                if (mounted) {
                  setState(() {
                    _targetScreen = LoginScreen();
                    _isLoading = false;
                  });
                }
              } else {
                await _handleLoggedInUser(user);
              }
            });
      }
    } catch (e) {
      print('Error checking auth state: $e');
      if (mounted) {
        setState(() {
          _targetScreen = LoginScreen();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLoggedInUser(User user) async {
    try {
      if (!user.emailVerified) {
        if (mounted) {
          setState(() {
            _targetScreen = VerifyEmailScreen(
              email: user.email ?? 'your email',
            );
            _isLoading = false;
          });
        }
        return;
      }

      bool hasCompletedOnboarding = await _checkIfCompletedOnboarding();

      if (!mounted) return; 

      if (hasCompletedOnboarding) {
        setState(() {
          _targetScreen = Homescreen();
          _isLoading = false;
        });
      } else {
        setState(() {
          _targetScreen = OnboardingScreen();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error handling logged in user: $e');
      if (mounted) {
        setState(() {
          _targetScreen = LoginScreen();
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _checkIfCompletedOnboarding() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .limit(1)
                .get();

        return allergenSnapshot.docs.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking onboarding: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen();
    }

    if (_isLoading) {
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
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(
                color: Color(0xFF00A19C),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Checking authentication...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _targetScreen ?? LoginScreen();
  }
}
