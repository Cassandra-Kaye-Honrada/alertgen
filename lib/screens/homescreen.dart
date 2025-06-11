import 'package:allergen/screens/ProfileScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/first_Aid_screens/emergencyScreen.dart';
import 'package:allergen/screens/scan_screen.dart'; // Add this import
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Homescreen extends StatefulWidget {
  @override
  _HomescreenState createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> allergens = [];
  bool isLoading = true;
  int _currentIndex = 0; // Add current index for bottom navigation

  @override
  void initState() {
    super.initState();
    fetchAllergenProfile();
  }

  void fetchAllergenProfile() async {
    if (user != null) {
      CollectionReference profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('profile');

      try {
        QuerySnapshot snapshot = await profileRef.get();
        List<Map<String, dynamic>> fetchedAllergens = [];

        for (var doc in snapshot.docs) {
          fetchedAllergens.add({'name': doc['name'] ?? '', 'id': doc.id});
        }

        setState(() {
          allergens = fetchedAllergens;
          isLoading = false;
        });
      } catch (e) {
        print('Error fetching allergen profile: $e');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _scanAction() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: 120.0, // Add bottom padding for the floating navigation
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Scan button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hello, QWERTY!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Row(
                        children: [
                          // Add Scan button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CameraScannerScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF0EA5E9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Scan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFFE6F7FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.menu,
                              color: Color(0xFF1890FF),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 30),

                  // Emergency Section
                  GestureDetector(
                    onLongPress:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EmergencyScreen()),
                        ),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFFF6F8FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Are you in an\nemergency?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textBlack,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Long press this area, your live location will be shared with the nearest help centre and your emergency contacts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          // Emergency light PNG - replace with your asset
                          Image.asset(
                            'assets/images/emergency_light.png', // Add your PNG here
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF4444),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.warning,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Allergen Profile Section
                  Text(
                    'Allergen Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),

                  SizedBox(height: 16),

                  // Allergen Icons Row
                  isLoading
                      ? Center(child: CircularProgressIndicator())
                      : Row(
                        children: [
                          for (int i = 0; i < allergens.length && i < 2; i++)
                            _buildAllergenIcon(allergens[i]['name']),
                          _buildAddAllergenIcon(),
                        ],
                      ),

                  SizedBox(height: 8),

                  // Allergen Labels Row
                  if (!isLoading)
                    Row(
                      children: [
                        for (int i = 0; i < allergens.length && i < 2; i++)
                          _buildAllergenLabel(allergens[i]['name']),
                        SizedBox(width: 60), // Space for add button
                      ],
                    ),

                  SizedBox(height: 20),

                  // Treatment Section
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.defaultbackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How to Treat Allergic Reaction',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FirstAidScreen(),
                                ),
                              ),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Recent History Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // History Items
                  Expanded(
                    child: ListView(
                      children: [
                        _buildHistoryItem(
                          'Ipsum dolor',
                          'Ipsum dolor',
                          '5 hrs ago',
                          Icons.warning,
                          Color(0xFFFCD34D),
                        ),
                        SizedBox(height: 12),
                        _buildHistoryItem(
                          'Ipsum dolor',
                          'Ipsum dolor',
                          '5 hrs ago',
                          Icons.check_circle,
                          Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Home button (left side)
                  GestureDetector(
                    onTap: () {
                      // Already on home screen, no navigation needed
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
                    child: Image.asset(
                      width: 24,
                      height: 24,
                      'assets/navigation/menu_active.png', // Active since we're on home
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.home,
                          color: Color(0xFF00BCD4),
                          size: 24,
                        );
                      },
                    ),
                  ),

                  // Scan button (center)
                  GestureDetector(
                    onTap: _scanAction,
                    child: Image.asset(
                      width: 24,
                      height: 24,
                      'assets/navigation/scan_inactive.png',
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.camera_alt,
                          color: Color(0xFF64748B),
                          size: 24,
                        );
                      },
                    ),
                  ),

                  // Profile/User button (right side)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                      // Add navigation to profile screen here when available
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserProfile()),
                      );
                    },
                    child: Image.asset(
                      width: 24,
                      height: 24,
                      'assets/navigation/Profile_inactive.png',
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Color(0xFF64748B),
                          size: 24,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenIcon(String allergenName) {
    return Container(
      margin: EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE0F2FE), width: 1),
            ),
            child: _getAllergenIcon(allergenName),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAllergenIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: Icon(Icons.add, color: Color(0xFF64748B), size: 24),
    );
  }

  Widget _buildAllergenLabel(String label) {
    return Container(
      width: 66,
      margin: EdgeInsets.only(top: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _getAllergenIcon(String allergenName) {
    switch (allergenName.toLowerCase()) {
      case 'milk':
        return Icon(Icons.local_drink, color: Color(0xFF0EA5E9), size: 26);
      case 'cashew':
      case 'nuts':
      case 'nut':
        return Icon(Icons.eco, color: Color(0xFF0EA5E9), size: 26);
      case 'egg':
      case 'eggs':
        return Icon(Icons.egg, color: Color(0xFF0EA5E9), size: 26);
      case 'fish':
        return Icon(Icons.set_meal, color: Color(0xFF0EA5E9), size: 26);
      case 'wheat':
      case 'gluten':
        return Icon(Icons.grass, color: Color(0xFF0EA5E9), size: 26);
      case 'soy':
      case 'soybean':
        return Icon(Icons.agriculture, color: Color(0xFF0EA5E9), size: 26);
      case 'shellfish':
      case 'seafood':
        return Icon(Icons.phishing, color: Color(0xFF0EA5E9), size: 26);
      case 'peanut':
      case 'peanuts':
        return Icon(Icons.circle, color: Color(0xFF0EA5E9), size: 26);
      default:
        return Icon(Icons.warning, color: Color(0xFF0EA5E9), size: 26);
    }
  }

  Widget _buildHistoryItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description, color: Color(0xFF64748B), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, color: iconColor, size: 20),
              SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
