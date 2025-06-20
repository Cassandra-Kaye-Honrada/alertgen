import 'dart:io';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileDetailsScreen extends StatefulWidget {
  @override
  State<EditProfileDetailsScreen> createState() =>
      _EditProfileDetailsScreenState();
}

class _EditProfileDetailsScreenState extends State<EditProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  File? _imageFile;
  bool isSaving = false;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      firstNameController.text = data['firstName'] ?? '';
      lastNameController.text = data['lastName'] ?? '';
      ageController.text = data['age']?.toString() ?? '';
      imageUrl = data['imageUrl'];
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? uploadedImageUrl = imageUrl;

      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}');
        await ref.putFile(_imageFile!);
        uploadedImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'imageUrl': uploadedImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSaving = false);
    }
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
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0.5,
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
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage:
                                  _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : (imageUrl != null &&
                                                  imageUrl!.isNotEmpty
                                              ? NetworkImage(imageUrl!)
                                              : null)
                                          as ImageProvider?,
                              child:
                                  _imageFile == null &&
                                          (imageUrl == null ||
                                              imageUrl!.isEmpty)
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
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter first name'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Enter last name'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter age';
                            }
                            final age = int.tryParse(value.trim());
                            if (age == null || age <= 0) {
                              return 'Enter valid age';
                            }
                            return null;
                          },
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isSaving ? null : _saveProfile,
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
                                  ? const SizedBox(
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
