import 'package:allergen/scanHistoryScreen.dart';
import 'package:allergen/screens/ProfileScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/first_Aid_screens/emergencyScreen.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'AllergenProfileScreen.dart'; // Add this import

class Homescreen extends StatefulWidget {
  @override
  _HomescreenState createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> allergens = [];
  String username = 'User'; // Add username state variable
  bool isLoading = true;
  int _currentIndex = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Use post frame callback to ensure widget is built before making async calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _safeInitialization();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _safeInitialization() async {
    try {
      // Fetch both username and allergens concurrently
      await Future.wait([fetchUsername(), fetchAllergenProfile()]);
    } catch (e) {
      print('Initialization error: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          isLoading = false;
          allergens = [];
          username = 'User';
        });
      }
    }
  }

  Future<void> fetchUsername() async {
    if (user == null || _isDisposed) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get()
          .timeout(Duration(seconds: 15));

      if (!_isDisposed && mounted && userDoc.exists) {
        setState(() {
          username = userDoc['username'] ?? 'User';
        });
      }
    } catch (e) {
      print('Error fetching username: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          username = 'User';
        });
      }
    }
  }

  // Improved fetchAllergenProfile method (better filtering and data handling)
  Future<void> fetchAllergenProfile() async {
    if (user == null || _isDisposed) return;

    try {
      CollectionReference profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('profile');

      // Filter specifically for allergen type documents like in OnboardingScreen
      QuerySnapshot snapshot = await profileRef
          .where('type', isEqualTo: 'allergen')
          .get()
          .timeout(Duration(seconds: 15));

      List<Map<String, dynamic>> fetchedAllergens = [];

      for (var doc in snapshot.docs) {
        if (doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          fetchedAllergens.add({
            'name': data['name']?.toString() ?? 'Unknown',
            'id': doc.id,
            'severity': (data['severity'] ?? 0.5).toDouble(),
            'type': data['type']?.toString() ?? 'allergen',
            'createdAt': data['createdAt'], // Include timestamp if needed
          });
        }
      }

      // Sort by creation date if available (newest first)
      fetchedAllergens.sort((a, b) {
        if (a['createdAt'] != null && b['createdAt'] != null) {
          Timestamp aTime = a['createdAt'] as Timestamp;
          Timestamp bTime = b['createdAt'] as Timestamp;
          return bTime.compareTo(aTime);
        }
        return 0;
      });

      if (!_isDisposed && mounted) {
        setState(() {
          allergens = fetchedAllergens;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching allergen profile: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          allergens = [];
          isLoading = false;
        });
      }
    }
  }

  // Add method to get severity color (from OnboardingScreen)
  Color _getSeverityColor(double severity) {
    if (severity < 0.33) return AppColors.mild; // Mild
    if (severity < 0.67) return AppColors.moderate; // Moderate
    return AppColors.dangerAlert; // Severe
  }

  // Method to refresh user data
  Future<void> refreshUserData() async {
    if (!_isDisposed && mounted) {
      setState(() {
        isLoading = true;
      });
      await _safeInitialization();
    }
  }

  void _scanAction() {
    if (!_isDisposed && mounted) {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CameraScannerScreen()),
        );
      } catch (e) {
        print('Navigation error to scanner: $e');
      }
    }
  }

  void _navigateToProfile() {
    if (!_isDisposed && mounted) {
      try {
        Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserProfile()),
            )
            .then((_) {
              // Reset the current index and refresh data when returning from profile
              if (!_isDisposed && mounted) {
                setState(() {
                  _currentIndex = 0;
                });
                // Refresh user data in case allergens were updated
                refreshUserData();
              }
            })
            .catchError((error) {
              print('Navigation error to profile: $error');
            });
      } catch (e) {
        print('Profile navigation error: $e');
      }
    }
  }

  Widget _buildAllergenGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Allergen icons in a scrollable row with always visible add button
        SizedBox(
          height: 80, // Adjust height based on your icon size
          child: Row(
            children: [
              // Scrollable allergen list
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allergens.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showAllergenDetails(allergens[index]),
                      child: _buildAllergenIconWithLabel(allergens[index]),
                    );
                  },
                ),
              ),

              // Always visible add button (outside the scrollable area)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: _buildAddAllergenIconWithLabel(),
              ),
            ],
          ),
        ),

        // Show "more" indicator below if there are many allergens
        if (allergens.length > 4) ...[
          SizedBox(height: 8),
          GestureDetector(
            onTap: _navigateToProfile,
            child: Text(
              'View all allergens',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],

        // Severity legend
        if (allergens.isNotEmpty) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSeverityLegendItem('Mild', AppColors.mild),
                SizedBox(width: 12),
                _buildSeverityLegendItem('Moderate', AppColors.moderate),
                SizedBox(width: 12),
                _buildSeverityLegendItem('Severe', AppColors.dangerAlert),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyAllergenState() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 48, color: AppColors.textGray),
          SizedBox(height: 12),
          Text(
            'No allergens added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add your allergens to get personalized food safety alerts',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfile()),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Add Allergens', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToEmergency() {
    if (!_isDisposed && mounted) {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EmergencyScreen()),
        ).catchError((error) {
          print('Navigation error to emergency: $error');
        });
      } catch (e) {
        print('Emergency navigation error: $e');
      }
    }
  }

  void _navigateToFirstAid() {
    if (!_isDisposed && mounted) {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FirstAidScreen()),
        ).catchError((error) {
          print('Navigation error to first aid: $error');
        });
      } catch (e) {
        print('First aid navigation error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: 120.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Scan button
                    _buildHeader(),
                    SizedBox(height: 30),

                    // Emergency Section
                    _buildEmergencySection(),
                    SizedBox(height: 30),

                    // Allergen Profile Section
                    _buildAllergenProfileSection(),
                    SizedBox(height: 20),

                    // Treatment Section
                    _buildTreatmentSection(),
                    SizedBox(height: 30),

                    // Recent History Section
                    _buildRecentHistorySection(),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Navigation
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hello, $username!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        GestureDetector(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ScanHistoryScreen()),
              ),
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Image.asset('assets/images/history.png', height: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencySection() {
    return GestureDetector(
      onLongPress: _navigateToEmergency,
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
            _buildEmergencyIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyIcon() {
    return Container(
      width: 60,
      height: 60,
      child: Image.asset('assets/images/emergency_light.png'),
    );
  }

  Widget _buildAllergenProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Allergen Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
            if (!isLoading && allergens.isNotEmpty)
              Row(
                children: [
                  Text(
                    '${allergens.length} allergen${allergens.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 14, color: AppColors.textGray),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllergenProfileScreen(),
                          ),
                        ),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: 16),

        // Enhanced allergen display with tap functionality
        isLoading
            ? Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
            : allergens.isEmpty
            ? _buildEmptyAllergenState()
            : _buildAllergenGrid(),
      ],
    );
  }

  Future<void> _handleRefresh() async {
    await refreshUserData();
  }

  // Method to show allergen details dialog
  void _showAllergenDetails(Map<String, dynamic> allergen) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              _getAllergenIcon(allergen['name']),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  allergen['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Severity Level',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getSeverityColor(allergen['severity']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    _getSeverityText(allergen['severity']),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Always carry your prescribed medication and inform others about your allergies.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Edit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Helper method to get severity text
  String _getSeverityText(double severity) {
    if (severity < 0.33) return 'Mild';
    if (severity < 0.67) return 'Moderate';
    return 'Severe';
  }

  // Method to handle scan history navigation with error handling
  void _navigateToScanHistory() {
    if (!_isDisposed && mounted) {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScanHistoryScreen()),
        ).catchError((error) {
          print('Navigation error to scan history: $error');
        });
      } catch (e) {
        print('Scan history navigation error: $e');
      }
    }
  }

  // Enhanced method to show snackbar messages
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.dangerAlert : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Method to handle network connectivity issues
  Future<bool> _checkConnectivity() async {
    try {
      // Simple connectivity check - you might want to use connectivity_plus package
      return true; // Placeholder - implement actual connectivity check
    } catch (e) {
      return false;
    }
  }

  // Method to show offline indicator
  Widget _buildOfflineIndicator() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      color: AppColors.dangerAlert,
      child: Text(
        'No internet connection',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Enhanced error handling for Firestore operations
  Future<T?> _safeFirestoreOperation<T>(Future<T> operation) async {
    try {
      return await operation.timeout(Duration(seconds: 15));
    } catch (e) {
      print('Firestore operation failed: $e');
      if (mounted) {
        _showSnackBar(
          'Connection error. Please check your internet.',
          isError: true,
        );
      }
      return null;
    }
  }

  // Method to handle deep links or navigation from notifications
  void _handleDeepLink(String? route) {
    if (route == null || !mounted) return;

    switch (route) {
      case '/profile':
        _navigateToProfile();
        break;
      case '/emergency':
        _navigateToEmergency();
        break;
      case '/scan':
        _scanAction();
        break;
      case '/history':
        _navigateToScanHistory();
        break;
      default:
        print('Unknown deep link route: $route');
    }
  }

  // Method to handle app lifecycle changes
  void _handleAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Refresh data when app comes back to foreground
        if (mounted && !isLoading) {
          refreshUserData();
        }
        break;
      case AppLifecycleState.paused:
        // Save any pending data when app goes to background
        break;
      default:
        break;
    }
  }

  // Method to validate user data integrity
  bool _validateUserData() {
    if (user == null) {
      _showSnackBar('Please log in again', isError: true);
      return false;
    }

    if (username.isEmpty) {
      username = 'User';
    }

    return true;
  }

  Widget _buildAllergenIconWithLabel(Map<String, dynamic> allergenData) {
    String allergenName = allergenData['name'];
    double severity = allergenData['severity'] ?? 0.5;
    Color severityColor = _getSeverityColor(severity);

    return Container(
      margin: EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
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
              // Severity indicator dot
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: severityColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            width: 66,
            child: Text(
              allergenName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAllergenIconWithLabel() {
    return Container(
      margin: EdgeInsets.only(right: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllergenProfileScreen(),
                  ),
                ),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE2E8F0), width: 1),
              ),
              child: Icon(Icons.add, color: Color(0xFF64748B), size: 24),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: 66,
            child: Text(
              'Add',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreAllergensIcon() {
    return Container(
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE0F2FE), width: 1),
            ),
            child: Center(
              child: Text(
                '+${allergens.length - 2}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0EA5E9),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: 66,
            child: Text(
              'more',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildTreatmentSection() {
    return Container(
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
                  'Learn essential first aid steps for allergic reactions.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _navigateToFirstAid,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistorySection() {
    return Column(
      children: [
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
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
        SizedBox(height: 16),

        // History Items
        Column(
          children: [
            _buildHistoryItem(
              'Food Scan Result',
              'Contains allergens',
              '5 hrs ago',
              Icons.warning,
              Color(0xFFFCD34D),
            ),
            SizedBox(height: 12),
            _buildHistoryItem(
              'Food Scan Result',
              'Safe to consume',
              '1 day ago',
              Icons.check_circle,
              Color(0xFF10B981),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Positioned(
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
            // Home button
            GestureDetector(
              onTap: () {
                if (!_isDisposed && mounted) {
                  setState(() {
                    _currentIndex = 0;
                  });
                }
              },
              child: Image.asset(
                'assets/navigation/menu_active.png',
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

            // Scan button
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

            // Profile button
            GestureDetector(
              onTap: () {
                if (!_isDisposed && mounted) {
                  setState(() {
                    _currentIndex = 2;
                  });
                  _navigateToProfile();
                }
              },
              child: Image.asset(
                'assets/navigation/Profile_inactive.png',
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
    );
  }

  // Enhanced allergen icon builder with Font Awesome icons
  Widget _getAllergenIcon(String allergenName) {
    final String name = allergenName.toLowerCase().trim();

    switch (name) {
      case 'milk':
      case 'dairy':
        return FaIcon(
          FontAwesomeIcons.glassWater,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'cashew':
      case 'nuts':
      case 'nut':
      case 'tree nuts':
        return FaIcon(
          FontAwesomeIcons.seedling,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'egg':
      case 'eggs':
        return FaIcon(
          FontAwesomeIcons.egg,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'fish':
        return FaIcon(
          FontAwesomeIcons.fish,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'wheat':
      case 'gluten':
        return FaIcon(
          FontAwesomeIcons.wheatAwn,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'soy':
      case 'soybean':
      case 'soya':
        return FaIcon(
          FontAwesomeIcons.leaf,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'shellfish':
      case 'seafood':
      case 'crustacean':
        return FaIcon(
          FontAwesomeIcons.shrimp,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'peanut':
      case 'peanuts':
        return FaIcon(
          FontAwesomeIcons.circleNodes,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'sesame':
        return FaIcon(
          FontAwesomeIcons.pepperHot,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'lupin':
        return FaIcon(
          FontAwesomeIcons.spa,
          color: AppColors.primaryColor3,
          size: 22,
        );
      default:
        return FaIcon(
          FontAwesomeIcons.triangleExclamation,
          color: AppColors.primaryColor3,
          size: 22,
        );
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
            child: Icon(icon, color: iconColor, size: 20),
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
                SizedBox(height: 2),
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
