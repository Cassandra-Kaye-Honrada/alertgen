import 'package:allergen/screens/profile_screen_items/scanHistoryScreen.dart';
import 'package:allergen/screens/ProfileScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/screens/result_screen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'profile_screen_items/AllergenProfileScreen.dart';

class Homescreen extends StatefulWidget {
  @override
  HomescreenState createState() => HomescreenState();
}

class HomescreenState extends State<Homescreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> allergens = [];
  String username = 'User';
  bool isLoading = true;
  int currentIndex = 0;
  bool isDisposed = false;
  late EmergencyService emergencyService;
  late Stream<List<Map<String, dynamic>>> recentHistoryStream;
  Map<String, File?> imageCache = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isDisposed) safeInitialization();
    });
    initializeEmergencyService();
    setupHistoryStream();
  }

  Future<void> initializeEmergencyService() async {
    emergencyService = EmergencyService();
    await emergencyService.initialize();
    setState(() => isLoading = false);
  }

  void setupHistoryStream() {
    if (user == null) {
      recentHistoryStream = Stream.value([]);
      return;
    }
    recentHistoryStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots()
        .asyncMap((snapshot) async {

          List<Map<String, dynamic>> historyItems = [];
          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String? fileName = data['fileName'] as String?;
            if (fileName == null) {
              final imagePath = data['imagePath'] as String?;
              if (imagePath != null) {
                fileName = imagePath.split('/').last;
              }
            }
            File? imageFile;
            if (fileName != null) {
              if (imageCache.containsKey(fileName)) {
                imageFile = imageCache[fileName];
              } else {
                imageFile = await downloadAndCacheImage(fileName);
                imageCache[fileName] = imageFile;
              }
            }
            historyItems.add({
              'id': doc.id,
              'dishName': data['dishName'] ?? 'Unknown Dish',
              'description': data['description'] ?? '',
              'ingredients': List<String>.from(data['ingredients'] ?? []),
              'allergens': data['allergens'] ?? [],
              'imageUrl': data['imageUrl'] ?? '',
              'fileName': data['fileName'] ?? '',
              'imagePath': data['imagePath'] ?? '',
              'timestamp': data['timestamp'],
              'scanDate': data['scanDate'] ?? '',
              'isOCRAnalysis': data['isOCRAnalysis'] ?? false,
              'cachedImage': imageFile,
            });
          }
          return historyItems;
        });
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  Future<void> safeInitialization() async {
    try {
      await Future.wait([fetchUsername(), fetchAllergenProfile()]);
    } catch (e) {
      if (!isDisposed && mounted) {
        setState(() {
          isLoading = false;
          allergens = [];
          username = 'User';
        });
      }
    }
  }

  Future<void> fetchUsername() async {
    if (user == null) 
    return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          username = data?['username'] ?? 'User';
        });
      }
    } catch (e) {
      setState(() {
        username = 'User';
      });
    }
  }

  Future<void> fetchAllergenProfile() async {
    if (user == null || isDisposed) return;
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('profile')
              .where('type', isEqualTo: 'allergen')
              .get();
      List<Map<String, dynamic>> fetchedAllergens = [];
      for (var doc in snapshot.docs) {
        if (doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          fetchedAllergens.add({
            'name': data['name']?.toString() ?? 'Unknown',
            'id': doc.id,
            'severity': (data['severity'] ?? 0.5).toDouble(),
            'type': data['type']?.toString() ?? 'allergen',
            'createdAt': data['createdAt'],
          });
        }
      }
      if (!isDisposed && mounted) {
        setState(() {
          allergens = fetchedAllergens;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!isDisposed && mounted) {
        setState(() {
          allergens = [];
          isLoading = false;
        });
      }
    }
  }

  Color getSeverityColor(double severity) {
    if (severity < 0.33) return AppColors.mild;
    if (severity < 0.67) return AppColors.moderate;
    return AppColors.dangerAlert;
  }

  String getSeverityText(double severity) {
    if (severity < 0.33) return 'Mild';
    if (severity < 0.67) return 'Moderate';
    return 'Severe';
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Unknown time';
      }
    } else {
      return 'Unknown time';
    }
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hr${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }

  Future<File?> getCachedImage(String fileName) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';
      final File file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return await downloadAndCacheImage(fileName);
    } catch (e) {
      return null;
    }
  }

  void navigateToResultScreen(Map<String, dynamic> historyItem) async {
    try {
      final dishName = historyItem['dishName'] ?? 'Unknown Dish';
      final description =
          historyItem['description'] ?? 'No description available';
      final ingredients = List<String>.from(historyItem['ingredients'] ?? []);
      final allergenData = historyItem['allergens'] as List<dynamic> ?? [];
      final bool isOCRAnalysis = historyItem['isOCRAnalysis'] as bool ?? false;
      String? fileName = historyItem['fileName'] as String?;
      if (fileName == null) {
        final imagePath = historyItem['imagePath'] as String?;
        if (imagePath != null) {
          fileName = imagePath.split('/').last;
        }
      }
      final List<AllergenInfo> allergens =
          allergenData.map((allergen) {
            final allergenMap = allergen as Map<String, dynamic>;
            return AllergenInfo(
              name: allergenMap['name'] ?? 'Unknown',
              riskLevel: allergenMap['riskLevel'] ?? 'mild',
              symptoms: List<String>.from(allergenMap['symptoms'] ?? []),
            );
          }).toList();
      if (fileName == null) return;
      File? imageFile = historyItem['cachedImage'];
      if (imageFile == null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
                ),
              ),
        );
        imageFile = await downloadAndCacheImage(fileName);
        Navigator.of(context).pop();
      }
      if (imageFile == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ResultScreen(
                image: imageFile!,
                dishName: dishName,
                description: description,
                ingredients: ingredients,
                allergens: allergens,
                isOCRAnalysis: isOCRAnalysis,
                onIngredientsChanged: (updatedIngredients) {},
              ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
    }
  }

  Future<File?> downloadAndCacheImage(String fileName) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';
      final File file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('scan_images')
          .child(fileName);
      final String downloadURL = await storageRef.getDownloadURL();
      final http.Response response = await http.get(Uri.parse(downloadURL));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshUserData() async {
    if (!isDisposed && mounted) {
      setState(() {
        isLoading = true;
      });
      imageCache.clear();
      await safeInitialization();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: refreshUserData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildHeader(),
                      SizedBox(height: 30),
                      buildEmergencySection(),
                      SizedBox(height: 30),
                      buildAllergenProfileSection(),
                      SizedBox(height: 20),
                      buildTreatmentSection(),
                      SizedBox(height: 30),
                      buildRecentHistorySection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget buildHeader() {
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
                MaterialPageRoute(builder: (context) => ScanHistoryScreen()),
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

  Widget buildEmergencySection() {
    return GestureDetector(
      onLongPress: () {
        emergencyService.startEmergencyCallFromUI(context);
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE2E8F0)),
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
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Long press this area, your live location will be shared with the nearest help centre',
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
            Container(
              width: 60,
              height: 60,
              child: Image.asset('assets/images/emergency_light.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAllergenProfileSection() {
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
              GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllergenProfileScreen(),
                      ),
                    ),
                child: Text(
                  '${allergens.length} allergen${allergens.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 14, color: AppColors.textGray),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        isLoading
            ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
            : allergens.isEmpty
            ? buildEmptyAllergenState()
            : buildAllergenGrid(),
      ],
    );
  }

  Widget buildAllergenGrid() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allergens.length + 1,
        itemBuilder: (context, index) {
          if (index == allergens.length) {
            return buildAddAllergenIcon();
          }
          return buildAllergenIcon(allergens[index]);
        },
      ),
    );
  }

  Widget buildAllergenIcon(Map<String, dynamic> allergenData) {
    return Container(
      margin: EdgeInsets.only(right: 16),
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    border: Border.all(color: Color(0xFFE0F2FE)),
                  ),
                  child: getAllergenIcon(allergenData['name']),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: getSeverityColor(allergenData['severity']),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Flexible(
              child: Container(
                width: 66,
                child: Text(
                  allergenData['name'],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAddAllergenIcon() {
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
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Icon(Icons.add, color: Color(0xFF64748B), size: 24),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyAllergenState() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
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
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            UserProfile(emergencyService: EmergencyService()),
                  ),
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

  Widget buildTreatmentSection() {
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
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FirstAidScreen()),
                ),
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

  Widget buildRecentHistorySection() {
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
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScanHistoryScreen(),
                    ),
                  ),
              child: Text(
                'View all',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: recentHistoryStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }
            if (snapshot.hasError) {
              return Text('Error loading history');
            }
            final recentHistory = snapshot.data ?? [];
            if (recentHistory.isEmpty) {
              return buildEmptyHistoryState();
            }
            return Column(
              children:
                  recentHistory
                      .map(
                        (item) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: buildHistoryItem(item),
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget buildEmptyHistoryState() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: AppColors.textGray),
          SizedBox(height: 12),
          Text(
            'No scan history yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Start scanning food items to see your history here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget buildHistoryItem(Map<String, dynamic> item) {
    List<dynamic> allergensList = item['allergens'] ?? [];
    bool hasAllergens = allergensList.isNotEmpty;
    File? cachedImage = item['cachedImage'];
    return GestureDetector(
      onTap: () => navigateToResultScreen(item),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    cachedImage != null
                        ? Image.file(
                          cachedImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                        : Icon(
                          hasAllergens ? Icons.warning : Icons.check_circle,
                          color:
                              hasAllergens
                                  ? AppColors.dangerAlert
                                  : Colors.green,
                          size: 20,
                        ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['dishName'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    hasAllergens
                        ? 'Contains ${allergensList.length} allergen${allergensList.length > 1 ? 's' : ''}'
                        : 'Safe to consume',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        hasAllergens
                            ? AppColors.dangerAlert.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasAllergens ? Icons.warning : Icons.check_circle,
                        size: 12,
                        color:
                            hasAllergens ? AppColors.dangerAlert : Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        hasAllergens ? 'Warning' : 'Safe',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              hasAllergens
                                  ? AppColors.dangerAlert
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  getTimeAgo(item['timestamp']),
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomNavigation() {
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
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => setState(() => currentIndex = 0),
              child: Image.asset(
                'assets/navigation/menu_active.png',
                width: 24,
                height: 24,
                errorBuilder:
                    (context, error, stackTrace) =>
                        Icon(Icons.home, color: Color(0xFF64748B), size: 24),
              ),
            ),
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CameraScannerScreen(),
                    ),
                  ),
              child: Image.asset(
                'assets/navigation/scan_inactive.png',
                width: 24,
                height: 24,
                errorBuilder:
                    (context, error, stackTrace) => Icon(
                      Icons.camera_alt,
                      color: Color(0xFF64748B),
                      size: 24,
                    ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => currentIndex = 2);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            UserProfile(emergencyService: EmergencyService()),
                  ),
                );
              },
              child: Image.asset(
                'assets/navigation/Profile_inactive.png',
                width: 24,
                height: 24,
                errorBuilder:
                    (context, error, stackTrace) =>
                        Icon(Icons.person, color: Color(0xFF00BCD4), size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getAllergenIcon(String allergenName) {
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
}
