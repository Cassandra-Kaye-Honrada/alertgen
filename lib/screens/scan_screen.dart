import 'dart:convert';
import 'dart:io';

import 'package:allergen/screens/ProfileScreen.dart';
import 'package:allergen/screens/homescreen.dart';
import 'package:allergen/screens/result_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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

  // Camera variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  FlashMode _flashMode = FlashMode.auto;
  bool _isRearCamera = true;

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
    _initializeCamera();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras?.isNotEmpty == true) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isRearCamera = !_isRearCamera;
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();
    _cameraController = CameraController(
      _isRearCamera ? _cameras![0] : _cameras![1],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController?.value.isInitialized != true) return;

    try {
      _flashMode = _flashMode == FlashMode.auto
          ? FlashMode.always
          : _flashMode == FlashMode.always
              ? FlashMode.off
              : FlashMode.auto;

      await _cameraController!.setFlashMode(_flashMode);
      setState(() {});
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController?.value.isInitialized != true || loading) return;

    try {
      setState(() => loading = true);
      final XFile capturedImage = await _cameraController!.takePicture();
      final File imageFile = File(capturedImage.path);
      setState(() => _image = imageFile);
      await analyzeImage(imageFile);
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Error capturing image: $e', Colors.red);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 75);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          loading = true;
        });
        await analyzeImage(_image!);
      }
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController?.dispose();
    textRecognizer?.close();
    super.dispose();
  }

  Future<void> analyzeImage(File imageFile) async {
    if (textRecognizer == null) {
      setState(() => loading = false);
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

  String get _analysisPrompt => '''
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
- Automatically map them to their corresponding common allergen (e.g., albumin → egg, casein → milk).
- Use the common allergen name (not the technical term) in the "name" field of the allergens JSON.
- Do this mapping even if the term is not in a predefined list.

Your task is to ensure the output helps users easily understand potential allergen risks, even if the ingredients are listed in scientific or technical terms.
''';

  Future<void> analyzeWithText(String ocrText, File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final prompt = '$_analysisPrompt\n\nOCR text: $ocrText';
      final response = await model.generateContent([Content.text(prompt)]);
      await parseGeminiResponse(response.text ?? '', imageFile);
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> analyzeWithImage(File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final response = await model.generateContent([
        Content.multi([TextPart(_analysisPrompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      await parseGeminiResponse(response.text ?? '', imageFile);
    } catch (e) {
      setState(() => loading = false);
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
        allergens = (jsonData['allergens'] as List? ?? [])
            .map((a) => AllergenInfo.fromJson(a))
            .toList();
        loading = false;
      });

      await saveToFirebase(imageFile);
      _navigateToResults();
    } catch (e) {
      setState(() {
        dishName = 'Analysis Complete';
        description = response;
        ingredients = ['Unable to parse ingredients'];
        allergens = [];
        loading = false;
      });
      _navigateToResults();
    }
  }

  void _navigateToResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
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

  Future<void> saveToFirebase(File imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Please log in to save your scan results', Colors.red);
        return;
      }

      if (!await imageFile.exists()) return;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('food_images')
          .child(user.uid)
          .child(fileName);

      final uploadTask = storageRef.putFile(imageFile);
      final uploadResult = await uploadTask;
      final imageUrl = await uploadResult.ref.getDownloadURL();

      final scanData = {
        'dishName': dishName.isNotEmpty ? dishName : 'Unknown Dish',
        'description': description.isNotEmpty ? description : 'No description available',
        'ingredients': ingredients.isNotEmpty ? ingredients : [],
        'allergens': allergens
            .map((a) => {
                  'name': a.name,
                  'riskLevel': a.riskLevel,
                  'symptoms': a.symptoms,
                })
            .toList(),
        'imageUrl': imageUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'scanDate': DateTime.now().toIso8601String(),
        'userId': user.uid,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add(scanData);

      _showSnackBar('Scan results saved successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to save scan results: ${e.toString()}', Colors.red);
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
      final newAllergens = (jsonData['allergens'] as List? ?? [])
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
      builder: (context) => AlertDialog(
        title: const Text('How to Use'),
        content: const Text(
          '1. Point your camera at the food or select from gallery\n'
          '2. Use the center button to capture and analyze the food\n'
          '3. Use flash button to toggle flash modes\n'
          '4. View results with allergen information\n'
          '5. Check ingredients and risk levels',
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

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      default:
        return Icons.flash_auto;
    }
  }

  Widget _buildCameraControls() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.photo_library, () => pickImage(ImageSource.gallery)),
          _buildControlButton(_getFlashIcon(), _toggleFlash),
          if (_cameras != null && _cameras!.length > 1)
            _buildControlButton(Icons.flip_camera_ios, _switchCamera),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                _buildNavButton('assets/navigation/menu_inactive.png', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => Homescreen()))),
                const SizedBox(width: 70),
                _buildNavButton('assets/navigation/Profile_inactive.png', () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfile()))),
              ],
            ),
          ),
          _buildCenterCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildNavButton(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(assetPath, width: 24, height: 24),
    );
  }

  Widget _buildCenterCaptureButton() {
    return Positioned(
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
            onTap: loading ? null : _captureImage,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Image.asset('assets/navigation/scan_active.png', width: 24, height: 24),
          ),
        ),
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
        title: const Text('Food Scanner', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
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
          // Camera preview or captured image
          Positioned.fill(
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : _isCameraInitialized
                    ? CameraPreview(_cameraController!)
                    : Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
                        ),
                      ),
          ),

          // Scanner overlay
          if (_image == null && _isCameraInitialized)
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
                    Text('Analyzing food...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),

          _buildCameraControls(),
          _buildBottomNavigation(),
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
            Container(
              width: 250,
              height: 250,
              child: Stack(
                children: [
                  ...List.generate(4, (index) => _buildCornerBracket(index)),
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
            Positioned(
              bottom: -80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Position your food within the frame and tap to capture',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCornerBracket(int index) {
    final positions = [
      {'top': 0.0, 'left': 0.0, 'borders': ['top', 'left']},
      {'top': 0.0, 'right': 0.0, 'borders': ['top', 'right']},
      {'bottom': 0.0, 'left': 0.0, 'borders': ['bottom', 'left']},
      {'bottom': 0.0, 'right': 0.0, 'borders': ['bottom', 'right']},
    ];

    final pos = positions[index];
    return Positioned(
      top: pos['top'] as double?,
      left: pos['left'] as double?,
      right: pos['right'] as double?,
      bottom: pos['bottom'] as double?,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: (pos['borders'] as List).contains('top')
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            left: (pos['borders'] as List).contains('left')
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: (pos['borders'] as List).contains('right')
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: (pos['borders'] as List).contains('bottom')
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
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