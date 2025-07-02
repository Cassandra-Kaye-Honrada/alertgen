import 'dart:convert';
import 'dart:io';

import 'package:allergen/screens/ProfileScreen.dart';
import 'package:allergen/screens/homescreen.dart';
import 'package:allergen/screens/result_screen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
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
  bool isOCRAnalysis = false;
  List<String> alternativeProducts = [];

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
      _flashMode =
          _flashMode == FlashMode.auto
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
      setState(() => loading = false);
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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

      if (ocrText.isNotEmpty && _isLabeledProduct(ocrText)) {
        await analyzeOCRText(ocrText, imageFile);
      } else {
        await analyzeWithImage(imageFile);
      }
    } catch (e) {
      print('Error during OCR: $e');
      await analyzeWithImage(imageFile);
    }
  }

  bool _isLabeledProduct(String ocrText) {
    final lowerText = ocrText.toLowerCase();

    final labelKeywords = [
      'ingredients:',
      'ingredients',
      'contains:',
      'allergens:',
      'nutrition facts',
      'nutritional information',
      'manufactured by',
      'produced by',
      'best before',
      'expiry date',
      'exp date',
      'use by',
      'serving size',
      'calories',
      'total fat',
      'may contain',
      'allergen information',
      'mg',
      'g ',
      ' g',
      'ml',
      ' ml',
      'kcal',
      'kj',
      'sodium',
      'protein',
      'carbohydrate',
      'sugar',
      'barcode',
      'upc',
      'sku',
    ];

    bool hasLabelKeywords = labelKeywords.any(
      (keyword) => lowerText.contains(keyword),
    );

    bool hasIngredientPattern =
        lowerText.contains(',') && (lowerText.split(',').length >= 3);

    bool hasPercentages = RegExp(r'\d+%').hasMatch(lowerText);

    return hasLabelKeywords || hasIngredientPattern || hasPercentages;
  }

  String get _ocrAnalysisPrompt => '''
You are an expert food product analyzer with access to comprehensive knowledge of Filipino and international packaged food products. Your goal is to accurately identify products and extract ingredients from food labels using OCR text.

PRODUCT IDENTIFICATION STRATEGY:
1. Look for BRAND NAMES and PRODUCT NAMES in the OCR text
2. Use your knowledge of popular Filipino food brands and products
3. Cross-reference with known product lines from major manufacturers
4. Consider product categories (snacks, instant noodles, canned goods, etc.)
5. If unsure, provide the most likely product name based on visible text patterns

COMMON FILIPINO FOOD BRANDS TO RECOGNIZE:
- Lucky Me! (instant noodles)
- Nissin (Cup Noodles, instant noodles)
- Payless (crackers, biscuits)
- Ricoa (chocolates, candies)
- Argentina (corned beef, canned meat)
- CDO (processed meats, canned goods)
- Spam (canned meat)
- Monde Nissin (SkyFlakes, Fita, biscuits)
- Universal Robina Corporation products (Jack 'n Jill, etc.)
- San Miguel (various food products)
- Del Monte (canned fruits, sauces)
- Hunt's (tomato sauce, pasta sauce)
- Maggi (seasonings, instant noodles)
- Knorr (seasonings, soup mixes)
- Nestlé products
- Unilever products

OCR TEXT IMPROVEMENT TECHNIQUES:
1. Handle common OCR errors and misreadings
2. Recognize partial or fragmented text
3. Use context clues to reconstruct complete words
4. Account for different fonts, orientations, and text quality
5. Cross-reference ingredient patterns with known product types

INGREDIENT EXTRACTION RULES:
1. Look for "INGREDIENTS:" or similar sections in the text
2. Parse comma-separated ingredient lists carefully
3. Handle ingredients with parenthetical information (e.g., "wheat flour (enriched)")
4. Recognize technical/scientific ingredient names
5. Account for percentage indicators (e.g., "sugar 15%")
6. Process multi-line ingredient lists
7. Handle both English and Filipino ingredient names

COMMON FILIPINO INGREDIENT TRANSLATIONS:
- Asukal = Sugar
- Asin = Salt  
- Mantika = Oil
- Gatas = Milk
- Itlog = Egg
- Bagoong = Fermented fish paste
- Toyo = Soy sauce
- Suka = Vinegar
- Paminta = Black pepper
- Bawang = Garlic
- Sibuyas = Onion
- Harina = Flour
- Niyog/Gata = Coconut
- Mani = Peanut

TECHNICAL INGREDIENT MAPPING:
- Monosodium glutamate (MSG) = Flavor enhancer (generally safe)
- Sodium benzoate = Preservative
- Potassium sorbate = Preservative
- Ascorbic acid = Vitamin C
- Tocopherols = Vitamin E
- BHT/BHA = Antioxidants
- Carrageenan = Thickener
- Lecithin = Emulsifier
- Albumin, Ovalbumin → Eggs
- Casein, Whey, Lactose → Milk
- Natural/Artificial flavoring → Check source if specified

THE 9 ALLERGENS TO DETECT:
1. Milk (dairy, casein, whey, lactose, gatas)
2. Eggs (albumin, lecithin, ovalbumin, itlog)
3. Fish (anchovies, bagoong, fish sauce, dried fish, isda)
4. Shellfish (shrimp, crab, oyster sauce, alamang, hipon)
5. Tree nuts (cashew, almonds, etc. - NOT peanuts, NOT coconut)
6. Peanuts (mani, peanut oil, groundnuts)
7. Wheat (gluten, flour, bread crumbs, harina)
8. Soy (soy sauce, tofu, soybean oil, toyo)
9. Sesame (sesame oil, tahini, linga)

ALLERGEN DETECTION RULES:
- Only detect allergens explicitly present in ingredient text
- Map technical/scientific names to common allergens
- Consider cross-contamination warnings ("may contain", "processed in facility")
- Filipino coconut products (gata, niyog) = SAFE (not tree nuts)
- Be conservative - only flag confirmed allergens
- Check for hidden sources (e.g., lecithin often from soy)

PRODUCT NAME DETERMINATION LOGIC:
1. Extract brand name from OCR text (usually prominently displayed)
2. Extract product variant/flavor (e.g., "Chicken Flavor", "Original")
3. Combine into full product name format: "Brand Product Variant"
4. If brand unclear, use product category + key descriptors
5. Cross-reference with known product databases and popular items
6. Prioritize accuracy - use "Unidentified [Category] Product" if uncertain

OCR ERROR CORRECTION PATTERNS:
- "0" often misread as "O" or "D"
- "1" often misread as "I" or "l"
- "5" often misread as "S"
- "8" often misread as "B"
- Fragmented words should be reconstructed using context
- Handle rotated or distorted text interpretations

Return JSON with this exact structure:
{
  "dishName": "Specific product brand and name (e.g., 'Lucky Me! Pancit Canton Sweet Style', 'Nissin Cup Noodles Beef Flavor')",
  "description": "Brief description including product category, key features, and brand information",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
  "allergens": [
    {
      "name": "One of the 9 allergens only",
      "riskLevel": "severe|moderate|mild|safe",
      "symptoms": ["specific symptom1", "specific symptom2"],
      "source": "specific ingredient that contains this allergen"
    }
  ]
}

CRITICAL REQUIREMENTS:
1. Use your knowledge of popular food products to make accurate product identifications
2. Cross-reference OCR text patterns with known brand and product names
3. Handle OCR errors intelligently using context and product knowledge
4. Extract ingredients thoroughly, including additives and preservatives
5. Only detect allergens that are actually present in the ingredient list
6. Provide specific, recognizable product names when possible
''';

  String get _imageAnalysisPrompt => '''
You are an expert Filipino food identification and allergen detection system. Your primary goal is ACCURATE DISH IDENTIFICATION based on visual characteristics.

CRITICAL IDENTIFICATION RULES:
1. Look carefully at the VISUAL CHARACTERISTICS of the dish
2. Identify based on what you SEE, not assumptions
3. Be SPECIFIC with Filipino dish names - avoid generic terms

COMMON FILIPINO DISHES - VISUAL IDENTIFICATION GUIDE:

GINILING (Ground Pork/Beef):
- Small, minced/ground meat pieces
- Usually brown/dark colored from cooking
- May have diced vegetables (carrots, potatoes, onions)
- Sauce-based, often tomato-based
- NOT the same as Picadillo (which has specific Spanish influences)

DINENGDENG:
- Clear, light-colored broth/soup
- Mixed vegetables clearly visible (squash, okra, string beans, etc.)
- Often has bagoong (fermented fish paste) - grayish
- Vegetables should look boiled/steamed in broth
- NOT Pesang Isda (which is primarily fish in clear broth)
- NOT Ginisang Isda (which is sautéed fish with vegetables, no broth)

SINIGANG NA ISDA:
- Clear fish soup/broth
- Whole fish pieces or fish fillets clearly visible
- Usually has ginger, onions, some vegetables
- Broth-based with fish as primary protein

GINISANG ISDA:
- Sautéed/fried fish with vegetables
- Fish pieces clearly visible, usually browned/fried
- Vegetables mixed with fish, minimal liquid
- More dry preparation than soup-like

PICADILLO:
- Ground meat with specific Spanish-style preparation
- Often has raisins, hard-boiled eggs
- Tomato-based sauce, sweeter flavor profile
- Different from simple giniling

OTHER KEY DISHES:
- ADOBO: Dark, soy sauce-colored meat (pork/chicken), glossy appearance
- SINIGANG: Sour soup, clear/light broth, vegetables, meat/seafood,
- KARE-KARE: Thick, orange/brown peanut sauce, oxtail/beef, vegetables
- PINAKBET: Mixed vegetables with bagoong, minimal liquid

THE 9 ALLERGENS TO DETECT:
1. Milk (dairy, casein, whey, lactose)
2. Eggs (albumin, lecithin, ovalbumin)
3. Fish (anchovies, bagoong, fish sauce, dried fish)
4. Shellfish (shrimp, crab, oyster sauce, alamang)
5. Tree nuts (cashew, almonds, etc. - NOT peanuts)
6. Peanuts (mani, peanut oil)
7. Wheat (gluten, flour, bread crumbs)
8. Soy (soy sauce, tofu, soybean oil)
9. Sesame (sesame oil, tahini)

ALLERGEN DETECTION RULES:
- Base detection on VISIBLE ingredients and known dish composition
- Traditional Adobo = SOY allergen (from soy sauce)
- Dinengdeng = FISH allergen (from bagoong)
- Dishes with visible fish/seafood = FISH/SHELLFISH allergens
- Coconut milk/gata = SAFE (not tree nut)
- Only detect allergens you can CONFIRM are present

Return JSON with this exact structure:
{
  "dishName": "Exact Filipino dish name based on visual identification",
  "description": "Brief description of the dish characteristics and preparation method",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
  "allergens": [
    {
      "name": "One of the 9 allergens only",
      "riskLevel": "severe|moderate|mild|safe",
      "symptoms": ["specific symptom1", "specific symptom2"],
      "source": "specific ingredient that contains this allergen"
    }
  ]
}

CRITICAL ACCURACY REQUIREMENTS:
- If you see ground meat with vegetables in sauce = likely "Giniling", NOT "Picadillo"
- If you see vegetables in clear broth with bagoong = "Dinengdeng", NOT "Pesang Isda" or "Ginisang Isda"
- Look at preparation method: soup vs sautéed vs stewed
- Be conservative: if unsure between similar dishes, choose the more common/traditional preparation
''';

  Future<void> analyzeOCRText(String ocrText, File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      setState(() => isOCRAnalysis = true);

      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final prompt = '''$_ocrAnalysisPrompt

EXTRACTED TEXT FROM FOOD LABEL:
"$ocrText"

DETAILED ANALYSIS INSTRUCTIONS:

1. PRODUCT IDENTIFICATION:
   - Scan the OCR text for brand names (usually in larger text/prominent position)
   - Look for product line names (e.g., "Cup Noodles", "Pancit Canton")
   - Identify flavor variants (e.g., "Beef", "Chicken", "Sweet Style")
   - Use your knowledge of Filipino food brands to make accurate identifications
   - If text is fragmented, use context clues to reconstruct the full product name

2. OCR ERROR CORRECTION:
   - Apply common OCR error patterns to improve text interpretation
   - Use product knowledge to correct misread characters
   - Reconstruct fragmented words using context
   - Handle multiple text orientations and font variations

3. INGREDIENT EXTRACTION:
   - Look for ingredient list sections (may be preceded by "INGREDIENTS:", "CONTAINS:", etc.)
   - Parse comma-separated lists carefully
   - Handle multi-line ingredient lists
   - Include additives, preservatives, and technical ingredients
   - Map Filipino ingredient names to English equivalents

4. ALLERGEN DETECTION:
   - Only flag allergens that are explicitly present in the ingredient list
   - Use technical ingredient mapping (e.g., lecithin → soy, casein → milk)
   - Consider cross-contamination warnings if present
   - Be conservative and accurate in allergen identification

5. CONTEXT-BASED VALIDATION:
   - Cross-reference identified product with typical ingredients for that product type
   - Validate ingredient list against known formulations for similar products
   - Ensure consistency between product name and ingredient profile

Focus on providing the most accurate product identification possible using your knowledge of food products and brands, while maintaining precision in ingredient extraction and allergen detection.''';

      final response = await model.generateContent([Content.text(prompt)]);
      await parseGeminiResponse(response.text ?? '', imageFile);
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Error analyzing product label: $e', Colors.red);
    }
  }

  String _preprocessOCRText(String rawText) {
    String cleaned =
        rawText
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'[^\w\s\.\,\:\;\%\-\(\)]'), '')
            .trim();

    // Common OCR error corrections
    cleaned = cleaned
        .replaceAll(
          RegExp(r'\b0(?=[a-zA-Z])'),
          'O',
        ) // 0 before letters likely O
        .replaceAll(RegExp(r'\bl(?=[0-9])'), '1')
        .replaceAll(RegExp(r'\bS(?=[0-9])'), '5')
        .replaceAll(RegExp(r'\bB(?=[0-9])'), '8');

    return cleaned;
  }

  Future<void> analyzeWithImage(File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      setState(() => isOCRAnalysis = false);
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final prompt = '''$_imageAnalysisPrompt

VISUAL ANALYSIS INSTRUCTIONS:
Carefully examine this Filipino food image. Follow these steps:

1. VISUAL IDENTIFICATION (Most Important):
   - What cooking method do you see? (soup/broth, sautéed, stewed, fried)
   - What are the main ingredients visible?
   - What is the color and consistency of the dish?
   - Is there liquid/broth or is it more dry?

2. SPECIFIC DISH CHARACTERISTICS:
   - Ground meat in sauce = likely Giniling
   - Vegetables in clear broth = likely Dinengdeng
   - Fish in clear broth = likely Pesang Isda
   - Sautéed fish with vegetables (no broth) = likely Ginisang Isda

3. ALLERGEN DETECTION:
   - Only detect allergens from ingredients you can visually confirm or know are traditional in the identified dish
   - Be conservative and accurate

Base your identification primarily on what you can SEE in the image. Be specific with Filipino dish names.''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      await parseGeminiResponse(response.text ?? '', imageFile);
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Error analyzing image: $e', Colors.red);
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
        dishName = jsonData['dishName'] ?? 'Unknown Food Product';
        description = jsonData['description'] ?? 'No description available';
        ingredients = List<String>.from(jsonData['ingredients'] ?? []);
        allergens =
            (jsonData['allergens'] as List? ?? [])
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
        builder:
            (context) => ResultScreen(
              image: _image!,
              dishName: dishName,
              description: description,
              ingredients: ingredients,
              allergens: allergens,
              onIngredientsChanged: updateAllergens,
              isOCRAnalysis: isOCRAnalysis,
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
        'dishName': dishName.isNotEmpty ? dishName : 'Unknown Product',
        'description':
            description.isNotEmpty ? description : 'No description available',
        'ingredients': ingredients.isNotEmpty ? ingredients : [],
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
        'fileName': fileName,
        'isOCRAnalysis': isOCRAnalysis,
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
Based on these ingredients, identify allergens from the 9 common allergens only:
Milk, Eggs, Fish, Shellfish, Tree nuts, Peanuts, Wheat, Soy, Sesame

IMPORTANT: Only detect allergens that are ACTUALLY present in the listed ingredients. Be conservative and accurate.

Return JSON:
{
  "allergens": [
    {
      "name": "One of the 9 allergens",
      "riskLevel": "severe|moderate|mild|safe",
      "symptoms": ["symptom1", "symptom2"],
      "source": "specific ingredient causing allergen"
    }
  ]
}

Ingredients: ${newIngredients.join(', ')}

Allergen sources (only if the ingredient is actually listed):
- Bagoong/Fish sauce = Fish
- Oyster sauce/Alamang = Shellfish  
- Soy sauce/Toyo = Soy
- Coconut milk/Gata = Safe (not tree nut)
- Technical terms: albumin/ovalbumin → eggs, casein/whey/lactose → milk, lecithin → usually soy

If any technical ingredient terms are detected, map them to their corresponding common allergen and use the common allergen name in the response.
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
            title: const Text('Food Scanner'),
            content: const Text(
              '• Point camera at Filipino dishes or food product labels\n'
              '• For prepared dishes: Identifies specific Filipino dishes visually\n'
              '• For packaged products: Extracts ingredients from labels using OCR\n'
              '• Detects 9 common allergens in both cases\n'
              '• Automatically determines if scanning a dish or product label\n'
              '• Tap center button to capture and analyze\n'
              '• View detailed allergen risk levels',
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
          _buildControlButton(
            Icons.photo_library,
            () => pickImage(ImageSource.gallery),
          ),
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
                _buildNavButton(
                  'assets/navigation/menu_inactive.png',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Homescreen()),
                  ),
                ),
                const SizedBox(width: 70),
                _buildNavButton(
                  'assets/navigation/Profile_inactive.png',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              UserProfile(emergencyService: EmergencyService()),
                    ),
                  ),
                ),
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
            child:
                loading
                    ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                    : Image.asset(
                      'assets/navigation/scan_active.png',
                      width: 24,
                      height: 24,
                    ),
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
          // Camera preview or captured image
          Positioned.fill(
            child:
                _image != null
                    ? Image.file(_image!, fit: BoxFit.cover)
                    : _isCameraInitialized
                    ? CameraPreview(_cameraController!)
                    : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00BCD4),
                        ),
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
                    Text(
                      'Analyzing Filipino food...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Position Filipino dish within frame and tap to scan for accurate identification',
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

  Widget _buildCornerBracket(int index) {
    final positions = [
      {
        'top': 0.0,
        'left': 0.0,
        'borders': ['top', 'left'],
      },
      {
        'top': 0.0,
        'right': 0.0,
        'borders': ['top', 'right'],
      },
      {
        'bottom': 0.0,
        'left': 0.0,
        'borders': ['bottom', 'left'],
      },
      {
        'bottom': 0.0,
        'right': 0.0,
        'borders': ['bottom', 'right'],
      },
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
            top:
                (pos['borders'] as List).contains('top')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
            left:
                (pos['borders'] as List).contains('left')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
            right:
                (pos['borders'] as List).contains('right')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
            bottom:
                (pos['borders'] as List).contains('bottom')
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
