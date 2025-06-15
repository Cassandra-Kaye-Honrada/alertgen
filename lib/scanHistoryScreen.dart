import 'dart:io';
import 'dart:typed_data';
import 'package:allergen/screens/result_screen.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 640;

    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.defaultbackground,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 27.0),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text(
          'Scan History',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: Color(0xFF0B8FAC),
          ),
        ),
        centerTitle: true,
        toolbarHeight: 80,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading history',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No scan history found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start scanning to see your history here',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final groupedDocs = _groupDocumentsByDate(snapshot.data!.docs);
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 23,
              vertical: 20,
            ),
            child: Column(
              children:
                  groupedDocs.entries.map((entry) {
                    return Column(
                      children: [
                        _buildHistorySection(
                          entry.key,
                          entry.value,
                          isSmallScreen,
                          context,
                        ),
                        const SizedBox(height: 23),
                      ],
                    );
                  }).toList(),
            ),
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getHistoryStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Map<String, List<DocumentSnapshot>> _groupDocumentsByDate(
    List<DocumentSnapshot> docs,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;

      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateString = DateFormat('dd MMM, yyyy').format(date);

        if (!grouped.containsKey(dateString)) {
          grouped[dateString] = [];
        }
        grouped[dateString]!.add(doc);
      }
    }
    return grouped;
  }

  Widget _buildHistorySection(
    String date,
    List<DocumentSnapshot> docs,
    bool isSmallScreen,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            fontSize: isSmallScreen ? 14 : 16,
            color: const Color(0xFF1D2939),
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 8),
        ...docs.map(
          (doc) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildHistoryCard(doc, isSmallScreen, context),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(
    DocumentSnapshot doc,
    bool isSmallScreen,
    BuildContext context,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final cardHeight = isSmallScreen ? 76.0 : 84.0;
    final imageSize = isSmallScreen ? 48.0 : 53.0;

    final dishName = data['dishName'] ?? 'Unknown Dish';
    final timestamp = data['timestamp'] as Timestamp?;
    final allergens = data['allergens'] as List<dynamic>? ?? [];
    final ingredients = data['ingredients'] as List<dynamic>? ?? [];

    // Handle both fileName and imagePath (extract filename from path)
    String? fileName = data['fileName'] as String?;
    if (fileName == null) {
      final imagePath = data['imagePath'] as String?;
      if (imagePath != null) {
        fileName = imagePath.split('/').last;
      }
    }

    final isSuccess = allergens.isEmpty;

    String timeAgo = 'Unknown time';
    if (timestamp != null) {
      final difference = DateTime.now().difference(timestamp.toDate());
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}m ago';
      } else {
        timeAgo = 'Just now';
      }
    }

    return GestureDetector(
      onTap: () => _navigateToResult(context, doc),
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: isSmallScreen ? 15 : 17,
                top: isSmallScreen ? 14 : 15,
              ),
              child: Container(
                width: imageSize,
                height: isSmallScreen ? 47 : 52,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    fileName != null
                        ? FutureBuilder<String?>(
                          future: _getImageUrl(fileName),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasData && snapshot.data != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.image,
                                      color: Colors.grey[500],
                                      size: 24,
                                    );
                                  },
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }

                            return Icon(
                              Icons.image,
                              color: Colors.grey[500],
                              size: 24,
                            );
                          },
                        )
                        : Icon(Icons.image, color: Colors.grey[500], size: 24),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 16, 60, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dishName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF494949),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ingredients.length} ingredients',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                        color: Color(0xFF6C8797),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: isSmallScreen ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 8),
                  _buildStatusIcon(isSuccess),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 10,
                        color: Color(0xFF6C8797),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 7,
                          color: Color(0xFF6C8797),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isSuccess) {
    if (isSuccess) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: AppColors.mild,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 12),
      );
    } else {
      return Container(
        width: 20,
        height: 18,
        decoration: const BoxDecoration(
          color: AppColors.dangerAlert,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.warning, color: Colors.white, size: 12),
      );
    }
  }

  Future<String?> _getImageUrl(String fileName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated');
        return null;
      }

      // Clean the filename - remove any path separators
      final cleanFileName = fileName.split('/').last;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('food_images')
          .child(user.uid)
          .child(cleanFileName);

      print(
        'Attempting to get image URL for: food_images/${user.uid}/$cleanFileName',
      );
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error getting image URL for $fileName: $e');
      return null;
    }
  }

  Future<File?> _downloadAndCacheImage(String fileName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated');
        return null;
      }

      // Clean the filename - remove any path separators
      final cleanFileName = fileName.split('/').last;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('food_images')
          .child(user.uid)
          .child(cleanFileName);

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/$cleanFileName';
      final File tempFile = File(tempPath);

      // Check if file already exists in cache
      if (await tempFile.exists()) {
        print('Using cached image: $tempPath');
        return tempFile;
      }

      print('Downloading image from: food_images/${user.uid}/$cleanFileName');
      final Uint8List? data = await storageRef.getData();
      if (data != null) {
        await tempFile.writeAsBytes(data);
        print('Image cached successfully: $tempPath');
        return tempFile;
      }
      print('No data received from Firebase Storage');
      return null;
    } catch (e) {
      print('Error downloading image $fileName: $e');
      return null;
    }
  }

  void _navigateToResult(BuildContext context, DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;

      final dishName = data['dishName'] ?? 'Unknown Dish';
      final description = data['description'] ?? 'No description available';
      final ingredients = List<String>.from(data['ingredients'] ?? []);
      final allergenData = data['allergens'] as List<dynamic>? ?? [];

      String? fileName = data['fileName'] as String?;
      if (fileName == null) {
        final imagePath = data['imagePath'] as String?;
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

      if (fileName == null) {
        print('No fileName or imagePath found in document: ${doc.id}');
        print('Document data: $data');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image filename not found in database'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            ),
      );

      final File? imageFile = await _downloadAndCacheImage(fileName);
      Navigator.of(context).pop(); 

      if (imageFile == null) {
        print('Failed to download image: $fileName');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ResultScreen(
                image: imageFile,
                dishName: dishName,
                description: description,
                ingredients: ingredients,
                allergens: allergens,
                onIngredientsChanged: (updatedIngredients) async {
                  print('Ingredients updated: $updatedIngredients');
                },
              ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if open
      print('Error navigating to result: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening scan result: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
