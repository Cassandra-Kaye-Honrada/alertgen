import 'dart:io';
import 'package:allergen/screens/homescreen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileDetailsScreen extends StatefulWidget {
  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();

  File? _imageFile;
  bool isSaving = false;

  final Color primaryColor = Color(0xFF0891B2);

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('User not authenticated')));
        return;
      }

      print('Current user UID: ${user.uid}');
      String? imageUrl;

      if (_imageFile != null) {
        print('Uploading image...');
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(user.uid);

        print('Storage path: ${ref.fullPath}');

        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
        print('Image uploaded successfully. URL: $imageUrl');
      }

      print('Saving profile to Firestore...');
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'imageUrl': imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Profile saved successfully');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile saved successfully')));

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => Homescreen()));
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSaving = false);
    }
  }

  void skipProfile() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => Homescreen()));
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Complete Your Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: skipProfile,
            child: Text(
              'Skip',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage:
                                  _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : null,
                              child:
                                  _imageFile == null
                                      ? Icon(
                                        Icons.camera_alt,
                                        size: 32,
                                        color: Colors.grey.shade800,
                                      )
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        TextFormField(
                          controller: firstNameController,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter your first name'
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: lastNameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter your last name'
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Age',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your age';
                            }
                            final age = int.tryParse(value.trim());
                            if (age == null || age <= 0)
                              return 'Enter a valid age';
                            return null;
                          },
                        ),
                        const Spacer(),

                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isSaving ? null : saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A19C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child:
                              isSaving
                                  ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Save Profile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
