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

  Stream<QuerySnapshot> getHistory() {
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

  Map<String, List<DocumentSnapshot>> groupDocumentsByDate(
    List<DocumentSnapshot> docs,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateString = DateFormat('dd MMM, yyyy').format(date);
        grouped[dateString] = grouped[dateString] ?? [];
        grouped[dateString]!.add(doc);
      }
    }
    return grouped;
  }

  Future<String?> getImageUrl(String fileName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final cleanFileName = fileName.split('/').last;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('food_images')
          .child(user.uid)
          .child(cleanFileName);
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<File?> downloadAndCacheImage(String fileName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final cleanFileName = fileName.split('/').last;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('food_images')
          .child(user.uid)
          .child(cleanFileName);

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$cleanFileName';
      final file = File(tempPath);

      if (await file.exists()) return file;

      final data = await storageRef.getData();
      if (data != null) {
        await file.writeAsBytes(data);
        return file;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  void navigateToResult(BuildContext context, DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final dishName = data['dishName'] ?? 'Unknown Dish';
      final description = data['description'] ?? '';
      final ingredients = List<String>.from(data['ingredients'] ?? []);
      final allergensData = data['allergens'] as List<dynamic>? ?? [];
      final isOCRAnalysis = data['isOCRAnalysis'] as bool? ?? false;

      String? fileName = data['fileName'] ?? data['imagePath']?.split('/').last;
      if (fileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image filename not found')),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            ),
      );

      final imageFile = await downloadAndCacheImage(fileName);
      Navigator.of(context).pop();

      if (imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $fileName')),
        );
        return;
      }

      final allergens =
          allergensData.map((item) {
            final map = item as Map<String, dynamic>;
            return AllergenInfo(
              name: map['name'] ?? 'Unknown',
              riskLevel: map['riskLevel'] ?? 'mild',
              symptoms: List<String>.from(map['symptoms'] ?? []),
              source: map['source'] ?? '',
            );
          }).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ResultScreen(
                image: imageFile,
                dishName: dishName,
                description: description,
                ingredients: ingredients,
                allergens: allergens,
                isOCRAnalysis: isOCRAnalysis,
                onIngredientsChanged: (_) {},
              ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening result: $e')));
    }
  }

  Widget buildStatusIcon(bool isSuccess) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isSuccess ? AppColors.mild : AppColors.dangerAlert,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isSuccess ? Icons.check : Icons.warning,
        color: Colors.white,
        size: 12,
      ),
    );
  }

  Widget buildHistoryCard(
    DocumentSnapshot doc,
    bool isSmallScreen,
    BuildContext context,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final dishName = data['dishName'] ?? 'Unknown Dish';
    final timestamp = data['timestamp'] as Timestamp?;
    final allergens = data['allergens'] as List<dynamic>? ?? [];
    final ingredients = data['ingredients'] as List<dynamic>? ?? [];
    final isSuccess = allergens.isEmpty;

    String? fileName = data['fileName'] ?? data['imagePath']?.split('/').last;
    final imageSize = isSmallScreen ? 48.0 : 53.0;

    String timeAgo = 'Just now';
    if (timestamp != null) {
      final difference = DateTime.now().difference(timestamp.toDate());
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}m ago';
      }
    }

    return GestureDetector(
      onTap: () => navigateToResult(context, doc),
      child: Container(
        height: isSmallScreen ? 76 : 84,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: isSmallScreen ? 15 : 17),
              child: Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    fileName != null
                        ? FutureBuilder<String?>(
                          future: getImageUrl(fileName),
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
                                ),
                              );
                            }
                            return const Icon(Icons.image, size: 24);
                          },
                        )
                        : const Icon(Icons.image, size: 24),
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
                  buildStatusIcon(isSuccess),
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

  Widget buildHistorySection(
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
        ...docs.map((doc) => buildHistoryCard(doc, isSmallScreen, context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Scan History',
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
      body: StreamBuilder<QuerySnapshot>(
        stream: getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading history'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No scan history found'));
          }

          final groupedDocs = groupDocumentsByDate(docs);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 23,
              vertical: 20,
            ),
            child: Column(
              children:
                  groupedDocs.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildHistorySection(
                          entry.key,
                          entry.value,
                          isSmallScreen,
                          context,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }).toList(),
            ),
          );
        },
      ),
    );
  }
}
