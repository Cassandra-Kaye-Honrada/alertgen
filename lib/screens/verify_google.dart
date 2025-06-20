import 'package:allergen/screens/onboarding.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isVerifying = false;
  String? statusMessage;

  Future<void> checkEmailVerified() async {
    setState(() {
      isVerifying = true;
      statusMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload();

      if (user != null && user.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OnboardingScreen()),
        );
      } else {
        setState(() {
          statusMessage = 'Email not verified yet. Please check again.';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      setState(() {
        isVerifying = false;
      });
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email resent.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend verification email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.email_outlined,
                color: Color(0xFF2563EB),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Check your email',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a verification link to\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: resendVerificationEmail,
                child: const Text(
                  "Resend Email",
                  style: TextStyle(color: Color(0xFF2563EB)),
                ),
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(statusMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isVerifying ? null : checkEmailVerified,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    isVerifying
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('I Verified My Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
