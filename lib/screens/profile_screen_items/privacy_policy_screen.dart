import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: AppColors.defaultbackground,
      // appBar: AppBar(
      //   backgroundColor: AppColors.primary,
      //   elevation: 0,
      //   title: const Text(
      //     'Privacy Policy',
      //     style: TextStyle(
      //       color: Colors.white,
      //       fontSize: 20,
      //       fontWeight: FontWeight.w600,
      //     ),
      //   ),
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back, color: Colors.white),
      //     onPressed: () => Navigator.pop(context),
      //   ),
      // ),
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Information We Collect
            _buildSection(
              'Information We Collect',
              'We collect the following information to provide our services:\n\n'
                  '• Photos of food products and ingredient labels you upload\n'
                  '• Personal allergy profile information\n'
                  '• Scan history and analysis results\n'
                  '• Account information (username, email)\n'
                  '• App usage data and preferences',
            ),

            // How We Use Your Information
            _buildSection(
              'How We Use Your Information',
              'We use your information to:\n\n'
                  '• Provide allergen detection and food analysis\n'
                  '• Maintain your allergy profile and preferences\n'
                  '• Improve our AI recognition algorithms\n'
                  '• Send important app updates and notifications\n'
                  '• Provide customer support',
            ),

            // Information Storage
            _buildSection(
              'Information Storage',
              'Your data is stored as follows:\n\n'
                  '• Personal allergy profiles are stored locally on your device\n'
                  '• Account data is securely stored using Firebase\n'
                  '• Food photos are temporarily stored for 90 days\n'
                  '• All data transmission uses encryption',
            ),

            // Information Sharing
            _buildSection(
              'Information Sharing',
              'We do not sell, trade, or share your personal information with third parties, except:\n\n'
                  '• When required by law\n'
                  '• To protect our rights and safety\n'
                  '• With your explicit consent\n'
                  '• With service providers who help us operate the app',
            ),

            // Your Rights
            _buildSection(
              'Your Rights',
              'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Correct inaccurate information\n'
                  '• Delete your account and data\n'
                  '• Withdraw consent for data processing',
            ),

            // Disclaimer
            _buildDisclaimerCard(),

            const SizedBox(height: 24),

            // Contact Information
            _buildContactCard(),

            const SizedBox(height: 24),

            // Last Updated
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Last updated: June 20, 2025',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            color: AppColors.textGray,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mildBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.mild.withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: AppColors.mild, size: 20),
              SizedBox(width: 8),
              Text(
                'Important Disclaimer',
                style: TextStyle(
                  color: AppColors.textBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'AlertGen provides informational content only and does NOT constitute medical advice. Always consult healthcare professionals for allergy-related decisions. We are not responsible for the accuracy of ingredient data or any allergic reactions.',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Us',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.email, color: AppColors.primaryColor2Teal, size: 18),
              SizedBox(width: 8),
              Text(
                'alertgenn@gmail.com',
                style: TextStyle(color: AppColors.textGray, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'For questions about this privacy policy or your data.',
            style: TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
