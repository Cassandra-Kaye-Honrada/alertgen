import 'package:allergen/screens/edit_profile.dart';
import 'package:allergen/screens/login.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../EmergencyContactScreen.dart';
import 'AllergenProfileScreen.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({Key? key}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  int _currentIndex = 2; // Profile is active
  String username = 'Loading...';
  int allergenCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await Future.wait([fetchUserProfile(), loadAllergenCount()]);
    setState(() {
      isLoading = false;
    });
  }

  String firstName = '';
  String lastName = '';
  String? profileImageUrl;

  Future<void> fetchUserProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          setState(() {
            firstName = userDoc['firstName'] ?? '';
            lastName = userDoc['lastName'] ?? '';
            username = "$firstName $lastName";
            profileImageUrl = userDoc['imageUrl'];
          });
        }
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      setState(() {
        username = 'User';
      });
    }
  }

  Future<void> loadAllergenCount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot profileSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        setState(() {
          allergenCount = profileSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error loading allergen count: $e');
      setState(() {
        allergenCount = 0;
      });
    }
  }

  void _scanAction() {
    // Handle scan action
    print('Scan button pressed');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraScannerScreen()),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Log out',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: const BorderSide(color: Color(0xFF1AA2CC)),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1AA2CC),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      _performLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1AA2CC),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Yes, Log out',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _performLogout() {
    // Add your logout logic here
    // For example: clear user data, tokens, etc.
    print('User logged out');

    // Navigate to login screen or initial screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LoginScreen()));

    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Logged out successfully',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Color(0xFF1AA2CC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                color: AppColors.primaryColor3,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Header section with profile
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              // Profile title
                              const Text(
                                'Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 75),
                            ],
                          ),
                        ),
                        // White content section
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const SizedBox(height: 50),
                                // User name - now displays fetched username
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: AppColors.primaryColor3,
                                    fontSize: 26,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                // Stats section
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1AA2CC),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Allergen section - now displays actual count
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'ALLERGEN',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                fontSize: 12,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            Text(
                                              isLoading
                                                  ? '...'
                                                  : '$allergenCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w700,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Divider
                                      Container(
                                        width: 1,
                                        height: 60,
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                      // Scan history section
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.history,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'SCAN HISTORY',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                fontSize: 12,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const Text(
                                              '10',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w700,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Settings list
                                Column(
                                  children: [
                                    // First settings group
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildSettingItem(
                                            icon: Icons.person_outline,
                                            label: 'Personal Details',
                                            showBorder: true,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          EditProfileDetailsScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                          _buildSettingItem(
                                            icon: Icons.local_hospital_outlined,
                                            label: 'Allergen Profile',
                                            showBorder: true,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          AllergenProfileScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                          _buildSettingItem(
                                            icon: Icons.history,
                                            label: 'Scan History',
                                            showBorder: false,
                                          ),
                                          _buildSettingItem(
                                            icon: Icons.phone,
                                            label: 'Emergency Contact',
                                            showBorder: false,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) =>
                                                          EmergencyContactScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Second settings group
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildSettingItem(
                                            icon: Icons.info_outline,
                                            label: 'About',
                                            showBorder: true,
                                          ),
                                          _buildSettingItem(
                                            icon: Icons.help_center_outlined,
                                            label: 'Help Center',
                                            showBorder: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Privacy
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 1,
                                        ),
                                      ),
                                      child: _buildSettingItem(
                                        icon: Icons.shield_outlined,
                                        label: 'Privacy',
                                        showBorder: false,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Logout
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 1,
                                        ),
                                      ),
                                      child: _buildSettingItem(
                                        icon: Icons.logout,
                                        label: 'Log out',
                                        showBorder: false,
                                        textColor: const Color(0xFFEF4444),
                                        onTap: _showLogoutDialog,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 120,
                                    ), // Extra space for bottom navigation
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 100,
                      left: MediaQuery.sizeOf(context).width / 2 - 60,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child:
                              profileImageUrl != null &&
                                      profileImageUrl!.isNotEmpty
                                  ? Image.network(
                                    profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                  )
                                  : Container(
                                    color: AppColors.primaryColor3,
                                    child: const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Navigation - Fixed positioning
          Container(
            margin: const EdgeInsets.all(20),
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
                    setState(() {
                      _currentIndex = 0;
                    });
                    Navigator.pop(context);
                  },
                  child: Image.asset(
                    'assets/navigation/menu_inactive.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.home,
                        color: Color(0xFF64748B),
                        size: 24,
                      );
                    },
                  ),
                ),

                // Scan button (center)
                GestureDetector(
                  onTap: _scanAction,
                  child: Image.asset(
                    'assets/navigation/scan_inactive.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
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
                  },
                  child: Image.asset(
                    'assets/navigation/profile_active.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person,
                        color: Color(0xFF00BCD4),
                        size: 24,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required bool showBorder,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border:
            showBorder
                ? const Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                )
                : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: textColor ?? const Color(0xFF6B7280),
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: textColor ?? const Color(0xFF374151),
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: Color(0xFF9CA3AF),
        ),
        onTap:
            onTap ??
            () {
              // Handle navigation
              print('Tapped: $label');
            },
      ),
    );
  }
}
