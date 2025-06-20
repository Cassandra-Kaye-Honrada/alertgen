import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'About AlertGen',
          style: TextStyle(
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
            // App Logo and Name Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AlertGen',
                    style: TextStyle(
                      color: AppColors.textBlack,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: const Text(
                      'Advanced Allergen Detection',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor2Teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: AppColors.primaryColor2Teal,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // General Information Section
            _buildSection(
              'What is AlertGen?',
              'AlertGen is an innovative AI-powered Android application that utilizes advanced OCR (Optical Character Recognition) technology and artificial intelligence to detect allergens in both labeled and unlabeled foods. Our mission is to enhance food safety and empower individuals with food allergies by providing real-time allergen identification and personalized food alternatives.',
            ),

            // Key Features Section
            const Text(
              'Key Features',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              Icons.document_scanner,
              'OCR Scanning',
              'Advanced scanning of ingredient lists on food packaging with high accuracy text recognition.',
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              Icons.image_search,
              'AI Image Analysis',
              'Intelligent analysis of unlabeled foods through cutting-edge image recognition technology.',
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              Icons.person_pin,
              'Personalized Profiles',
              'Custom allergy profiles with real-time allergen alerts tailored to your specific needs.',
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              Icons.restaurant_menu,
              'Food Alternatives',
              'Smart suggestions for safe food alternatives based on your allergy profile and dietary preferences.',
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              Icons.medical_services,
              'Emergency Support',
              'Built-in first aid guide and emergency contact features for critical situations.',
            ),

            const SizedBox(height: 12),

            _buildFeatureCard(
              Icons.security,
              'Secure & Private',
              'Enterprise-grade security with local data storage and encrypted cloud backup options.',
            ),

            const SizedBox(height: 24),

            // Technology Stack Section
            _buildSection(
              'Technology Behind AlertGen',
              'AlertGen leverages state-of-the-art technologies to provide accurate and reliable allergen detection:',
            ),

            _buildTechList([
              'Advanced OCR Technology for precise text extraction from food labels',
              'Machine Learning algorithms trained on extensive food ingredient databases',
              'Computer Vision for unlabeled food identification and analysis',
              'Firebase Authentication for secure user account management',
              'Real-time ingredient database with continuous updates',
              'Cloud-based AI processing for enhanced accuracy and speed',
            ]),

            const SizedBox(height: 24),

            // App Capabilities Section
            const Text(
              'What AlertGen Can Do',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildCapabilityCard(Icons.check_circle, 'Detect Allergens', [
              'Nuts (tree nuts, peanuts)',
              'Dairy products and lactose',
              'Gluten and wheat-based ingredients',
              'Shellfish and seafood',
              'Eggs and egg derivatives',
              'Soy-based products',
              'Seeds (sesame, sunflower, etc.)',
              'And many more...',
            ]),

            const SizedBox(height: 16),

            _buildCapabilityCard(
              Icons.person_add,
              'Personalized Allergen Detection',
              [
                'Add your own custom allergens beyond common ones',
                'Create personalized allergy profiles for unique sensitivities',
                'Set up alerts for rare or specific food intolerances',
                'Manage multiple allergen profiles for different family members',
                'Track and monitor personalized allergen exposure',
              ],
            ),

            const SizedBox(height: 16),

            _buildCapabilityCard(Icons.analytics, 'Advanced Analysis', [
              'Hidden allergens in processed foods',
              'Cross-contamination warnings',
              'Ingredient derivative detection',
              'Nutritional information extraction',
              'Alternative ingredient suggestions',
            ]),

            const SizedBox(height: 24),

            // App Limitations Section
            _buildSection(
              'Current Limitations',
              'While AlertGen is highly advanced, please be aware of these current limitations:',
            ),

            _buildLimitationsList([
              'Performance may be affected by poor lighting, image quality, or device capabilities',
              'OCR accuracy can be compromised by text blurriness, unusual fonts, or damaged packaging',
              'Requires stable internet connection for AI analysis and ingredient database access',
              'May have difficulty with regional foods or combination dishes with unclear visual indicators',
              'Cross-reactive allergens are not automatically detected and must be manually added to profiles',
              'Food suggestions are limited to named products and may not cover all unlabeled meals',
            ]),

            const SizedBox(height: 24),

            // Development Team Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.group,
                        color: AppColors.primaryColor2Teal,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Development Team',
                        style: TextStyle(
                          color: AppColors.textBlack,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AlertGen is developed by a dedicated team of software engineers, AI specialists, and healthcare professionals committed to making food safety accessible to everyone.',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Our mission is to leverage cutting-edge technology to protect individuals with food allergies and create a safer dining experience for all.',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support and Feedback Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mildBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mild.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.support_agent,
                        color: AppColors.mild,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Support & Feedback',
                        style: TextStyle(
                          color: AppColors.textBlack,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'We value your feedback and are committed to continuously improving AlertGen. Your suggestions help us make the app safer and more effective for everyone.',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactButton(
                          icon: Icons.email,
                          label: 'General Support',
                          subtitle: 'alertgenn@gmail.com',
                          color: AppColors.primaryColor2Teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.textBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    'AlertGen - Making Food Safety Accessible',
                    style: TextStyle(
                      color: AppColors.textBlack,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Developed with ❤️ for the food allergy community',
                    style: TextStyle(color: AppColors.textGray, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Last updated: June 20, 2025',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            color: AppColors.textGray,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryColor2Teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryColor2Teal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechList(List<String> items) {
    return Column(
      children:
          items
              .map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryColor2Teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildCapabilityCard(IconData icon, String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.mild, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.mild,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildLimitationsList(List<String> items) {
    return Column(
      children:
          items
              .map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.moderate,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
