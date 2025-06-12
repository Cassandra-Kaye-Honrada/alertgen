<<<<<<< HEAD
import 'dart:convert';
import 'dart:io';
import 'package:allergen/screens/result_screen.dart';
=======
import 'package:allergen/screens/ProfileScreen.dart';
>>>>>>> 571adbb8ffa2ef53ce7feee2f9d7a2caaf598d20
import 'package:allergen/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

const apiKey = 'AIzaSyCzyd0ukiEilgPiJ29HNplB2UtWyOKCZkA';

class CameraScannerScreen extends StatefulWidget {
  @override
  _CameraScannerScreenState createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  File? _image;
  final picker = ImagePicker();
  bool loading = false;
  TextRecognizer? textRecognizer;
  String dishName = '';
  String description = '';
  List<String> ingredients = [];
  List<AllergenInfo> allergens = [];

  @override
  void initState() {
    super.initState();
    textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    textRecognizer?.close();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          loading = true;
        });
        await analyzeImage(_image!);
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> analyzeImage(File imageFile) async {
    if (textRecognizer == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer!.processImage(inputImage);
      final ocrText = recognizedText.text.trim();

      if (ocrText.isNotEmpty) {
        await analyzeWithText(ocrText, imageFile);
      } else {
        await analyzeWithImage(imageFile);
      }
    } catch (e) {
      await analyzeWithImage(imageFile);
    }
  }

  Future<void> analyzeWithText(String ocrText, File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() {
        loading = false;
      });
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final prompt = '''
Analyze this food image and return a JSON response with this exact structure:

{
  "dishName": "Name of the dish",
  "description": "Detailed description of the dish",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
  "allergens": [
    {
      "name": "Milk",
      "riskLevel": "severe",
      "symptoms": ["stomach pain", "bloating"]
    }
  ]
}

Risk levels should be: "severe", "moderate", "mild", or "safe"

Common allergens to check for: milk, eggs, fish, shellfish, tree nuts, peanuts, wheat, soy bean, sesame, mustard

If any technical or ambiguous ingredient terms are detected (e.g., "albumin", "casein", "lecithin", etc.), you must:

- Automatically map them to their corresponding **common allergen** (e.g., albumin → egg, casein → milk).
- Use the **common allergen name** (not the technical term) in the "name" field of the allergens JSON.
- Do this mapping even if the term is not in a predefined list — you are responsible for identifying and categorizing such terms accurately.

Your task is to ensure the output helps users easily understand potential allergen risks, even if the ingredients are listed in scientific or technical terms.

OCR text: $ocrText
''';

      final response = await model.generateContent([Content.text(prompt)]);
      await parseGeminiResponse(response.text ?? '', imageFile);
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> analyzeWithImage(File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() {
        loading = false;
      });
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();

      final prompt = '''
Analyze this food image and return a JSON response with this exact structure:

{
  "dishName": "Name of the dish",
  "description": "Detailed description of the dish",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
  "allergens": [
    {
      "name": "Milk",
      "riskLevel": "severe",
      "symptoms": ["stomach pain", "bloating"]
    }
  ]
}

Risk levels should be: "severe", "moderate", "mild", or "safe"

Common allergens to check for: milk, eggs, fish, shellfish, tree nuts, peanuts, wheat, soy bean, sesame, mustard

If any technical or ambiguous ingredient terms are detected (e.g., "albumin", "casein", "lecithin", etc.), you must:

- Automatically map them to their corresponding **common allergen** (e.g., albumin → egg, casein → milk).
- Use the **common allergen name** (not the technical term) in the "name" field of the allergens JSON.
- Do this mapping even if the term is not in a predefined list — you are responsible for identifying and categorizing such terms accurately.

Your task is to ensure the output helps users easily understand potential allergen risks, even if the ingredients are listed in scientific or technical terms.
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      await parseGeminiResponse(response.text ?? '', imageFile);
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> parseGeminiResponse(String response, File imageFile) async {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }

      final jsonData = json.decode(cleanResponse.trim());

      setState(() {
        dishName = jsonData['dishName'] ?? 'Unknown Dish';
        description = jsonData['description'] ?? 'No description available';
        ingredients = List<String>.from(jsonData['ingredients'] ?? []);
        allergens =
            (jsonData['allergens'] as List? ?? [])
                .map((a) => AllergenInfo.fromJson(a))
                .toList();
        loading = false;
      });

      await saveToFirebase(imageFile);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ResultScreen(
                image: _image!,
                dishName: dishName,
                description: description,
                ingredients: ingredients,
                allergens: allergens,
                onIngredientsChanged: updateAllergens,
              ),
        ),
      );
    } catch (e) {
      setState(() {
        dishName = 'Analysis Complete';
        description = response;
        ingredients = ['Unable to parse ingredients'];
        allergens = [];
        loading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ResultScreen(
                image: _image!,
                dishName: dishName,
                description: description,
                ingredients: ingredients,
                allergens: allergens,
                onIngredientsChanged: updateAllergens,
              ),
        ),
      );
    }
  }

  Future<void> saveToFirebase(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('food_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(imageFile);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('food_analysis').add({
        'dishName': dishName,
        'description': description,
        'ingredients': ingredients,
        'allergens':
            allergens
                .map(
                  (a) => {
                    'name': a.name,
                    'riskLevel': a.riskLevel,
                    'symptoms': a.symptoms,
                  },
                )
                .toList(),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving to Firebase: $e');
    }
  }

  Future<void> updateAllergens(List<String> newIngredients) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash-preview-04-17',
      apiKey: apiKey,
    );

    final prompt = '''
Based on these ingredients, identify potential allergens and return JSON:

{
  "allergens": [
    {
      "name": "Milk",
      "riskLevel": "severe",
      "symptoms": ["stomach pain", "bloating"]
    }
  ]
}

Ingredients: ${newIngredients.join(', ')}
Risk levels: "severe", "moderate", "mild", or "safe"
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      String cleanResponse = response.text ?? '';
      if (cleanResponse.contains('```json')) {
        cleanResponse = cleanResponse.split('```json')[1].split('```')[0];
      }

      final jsonData = json.decode(cleanResponse.trim());
      final newAllergens =
          (jsonData['allergens'] as List? ?? [])
              .map((a) => AllergenInfo.fromJson(a))
              .toList();

      setState(() {
        ingredients = newIngredients;
        allergens = newAllergens;
      });
    } catch (e) {
      print('Error updating allergens: $e');
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('How to Use'),
            content: const Text(
              '1. Point your camera at the food or select from gallery\n'
              '2. Use the center button to analyze the food\n'
              '3. View results with allergen information\n'
              '4. Check ingredients and risk levels',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Food Scanner',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main image display area
          Positioned.fill(
            child:
                _image != null
                    ? Image.file(_image!, fit: BoxFit.cover)
                    : Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 80,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Ready to scan food',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),

          // Scanner overlay when no image is selected
          if (_image == null)
            Center(child: ScannerOverlay(animation: _animation)),

          // Loading overlay
          if (loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00BCD4)),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing food...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Top controls (gallery and flash placeholders)
          Positioned(
            bottom: 100,
            left: 50,
            child: IconButton(
              onPressed: () => pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, color: Colors.white),
            ),
          ),

          Positioned(
            bottom: 100,
            right: 50,
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Flash not available for image analysis'),
                    backgroundColor: Color(0xFF00BCD4),
                  ),
                );
              },
              icon: const Icon(Icons.flash_auto, color: Colors.white),
            ),
          ),

          // Bottom navigation bar
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // White rounded container
                Container(
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
                      // Home/Menu button (left side)
                      GestureDetector(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => Homescreen()),
                            ),
                        child: Image.asset(
                          width: 24,
                          height: 24,
                          'assets/navigation/menu_inactive.png',
                        ),
                      ),

                      // Spacer for center button
                      const SizedBox(width: 70),

                      // Profile button (right side)
                      GestureDetector(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => UserProfile()),
                            ),
                        child: Image.asset(
                          width: 24,
                          height: 24,
                          'assets/navigation/Profile_inactive.png',
                        ),
                      ),
                    ],
                  ),
                ),

                // Elevated center scan button
                Positioned(
                  top: -20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        child: Image.asset(
                          width: 24,
                          height: 24,
                          'assets/navigation/scan_active.png',
                        ),
                        onTap:
                            loading
                                ? null
                                : () => pickImage(ImageSource.camera),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;

  const ScannerOverlay({Key? key, required this.animation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Scanning frame
            Container(
              width: 250,
              height: 250,
              child: Stack(
                children: [
                  // Corner brackets
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 3),
                          left: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 3),
                          right: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 3),
                          left: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 3),
                          right: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),

                  // Animated scanning line
                  Positioned(
                    top: animation.value * 220,
                    left: 15,
                    right: 15,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Instruction text
            Positioned(
              bottom: -80,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Position your food within the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class AllergenInfo {
  final String name;
  final String riskLevel;
  final List<String> symptoms;

  AllergenInfo({
    required this.name,
    required this.riskLevel,
    required this.symptoms,
  });

  factory AllergenInfo.fromJson(Map<String, dynamic> json) {
    return AllergenInfo(
      name: json['name'] ?? '',
      riskLevel: json['riskLevel'] ?? 'safe',
      symptoms: List<String>.from(json['symptoms'] ?? []),
    );
  }

  Color get color {
    switch (riskLevel.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String get iconPath {
    final firstLetter = name[0].toUpperCase();
    final rest = name.substring(1).toLowerCase();
    return 'assets/allergens/$firstLetter$rest.png';
  }
}
