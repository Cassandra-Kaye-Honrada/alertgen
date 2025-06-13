import 'dart:io';
import 'dart:ui';
import 'package:allergen/scanHistoryScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/ingredientmodal.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ResultScreen extends StatefulWidget {
  final File image;
  final String dishName;
  final String description;
  final List<String> ingredients;
  final List<AllergenInfo> allergens;
  final Function(List<String>) onIngredientsChanged;

  const ResultScreen({
    Key? key,
    required this.image,
    required this.dishName,
    required this.description,
    required this.ingredients,
    required this.allergens,
    required this.onIngredientsChanged,
  }) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> currentIngredients;
  late List<AllergenInfo> currentAllergens;
  bool isEditing = false;
  bool isUpdatingAllergens = false;
  List<AlternativeProduct> alternativeProducts = []; // ADD THIS
  String? documentId;

  // API Configuration
  static const String _apiKey = 'AIzaSyCzyd0ukiEilgPiJ29HNplB2UtWyOKCZkA';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    currentIngredients = List.from(widget.ingredients);
    currentAllergens = List.from(widget.allergens);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  Future _saveChanges() async {
    setState(() {
      isEditing = false;
      isUpdatingAllergens = true;
    });

    try {
      // Update allergens based on new ingredients using AI
      await _updateAllergens();

      // Update in Firebase database
      await _updateInFirebase();

      // Generate alternative products based on allergens
      await _generateAlternativeProducts();

      // Notify parent of ingredient changes
      await widget.onIngredientsChanged(currentIngredients);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Changes saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving changes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isUpdatingAllergens = false;
      });
    }
  }

  // ADD THIS NEW METHOD TO UPDATE FIREBASE
  Future<void> _updateInFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // If we don't have documentId, find the most recent document
      if (documentId == null) {
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('history')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          documentId = querySnapshot.docs.first.id;
        } else {
          throw Exception('No document found to update');
        }
      }

      // Update the document with new ingredients and allergens
      final updateData = {
        'ingredients': currentIngredients,
        'allergens':
            currentAllergens
                .map(
                  (a) => {
                    'name': a.name,
                    'riskLevel': a.riskLevel,
                    'symptoms': a.symptoms,
                  },
                )
                .toList(),
        'alternativeProducts':
            alternativeProducts
                .map(
                  (p) => {
                    'name': p.name,
                    'description': p.description,
                    'imageUrl': p.imageUrl,
                    'price': p.price,
                    'allergenFree': p.allergenFree,
                  },
                )
                .toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .doc(documentId)
          .update(updateData);

      print('Successfully updated document in Firebase');
    } catch (e) {
      print('Error updating Firebase: $e');
      throw e;
    }
  }

  // ADD THIS NEW METHOD TO GENERATE ALTERNATIVE PRODUCTS
  Future<void> _generateAlternativeProducts() async {
    if (currentAllergens.isEmpty) {
      // If no allergens, suggest general healthy alternatives
      alternativeProducts = [
        AlternativeProduct(
          name: 'Organic ${widget.dishName}',
          description: 'Organic version of this dish',
          imageUrl: '',
          price: 0.0,
          allergenFree: [],
        ),
        AlternativeProduct(
          name: 'Gluten-Free Alternative',
          description: 'Gluten-free version available',
          imageUrl: '',
          price: 0.0,
          allergenFree: ['gluten', 'wheat'],
        ),
        AlternativeProduct(
          name: 'Dairy-Free Option',
          description: 'Made without dairy products',
          imageUrl: '',
          price: 0.0,
          allergenFree: ['milk', 'dairy'],
        ),
      ];
      return;
    }

    try {
      // Generate alternatives based on detected allergens using AI
      final response = await _generateAlternativesWithAI();

      if (response != null && response['alternatives'] != null) {
        List<AlternativeProduct> newAlternatives = [];

        for (var alt in response['alternatives']) {
          newAlternatives.add(
            AlternativeProduct(
              name: alt['name'] ?? 'Alternative Product',
              description: alt['description'] ?? 'Safe alternative',
              imageUrl: alt['imageUrl'] ?? '',
              price: (alt['price'] ?? 0.0).toDouble(),
              allergenFree: List<String>.from(alt['allergenFree'] ?? []),
            ),
          );
        }

        setState(() {
          alternativeProducts = newAlternatives;
        });
      }
    } catch (e) {
      print('Error generating alternatives: $e');
      // Fallback alternatives
      setState(() {
        alternativeProducts = _getDefaultAlternatives();
      });
    }
  }

  // ADD THIS METHOD FOR AI-GENERATED ALTERNATIVES
  Future<Map<String, dynamic>?> _generateAlternativesWithAI() async {
    try {
      final allergenNames = currentAllergens.map((a) => a.name).join(', ');

      final prompt = '''
Generate 3 alternative food products that are safe for someone allergic to: $allergenNames

The original dish is: ${widget.dishName}

Please provide a JSON response with this structure:
{
  "alternatives": [
    {
      "name": "Alternative product name",
      "description": "Brief description why it's safe",
      "imageUrl": "",
      "price": 0.0,
      "allergenFree": ["list", "of", "allergens", "this", "avoids"]
    }
  ]
}

Focus on realistic alternatives that avoid the detected allergens.
Only return the JSON object, no additional text.
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.3,
          'topK': 1,
          'topP': 1,
          'maxOutputTokens': 1024,
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null) {
          String cleanedContent = content.toString().trim();
          if (cleanedContent.startsWith('```json')) {
            cleanedContent = cleanedContent.substring(7);
          }
          if (cleanedContent.endsWith('```')) {
            cleanedContent = cleanedContent.substring(
              0,
              cleanedContent.length - 3,
            );
          }

          return json.decode(cleanedContent);
        }
      }
    } catch (e) {
      print('Error generating alternatives with AI: $e');
    }

    return null;
  }

  // ADD THIS METHOD FOR DEFAULT ALTERNATIVES
  List<AlternativeProduct> _getDefaultAlternatives() {
    final allergenNames =
        currentAllergens.map((a) => a.name.toLowerCase()).toList();

    List<AlternativeProduct> defaults = [];

    if (allergenNames.contains('milk') || allergenNames.contains('dairy')) {
      defaults.add(
        AlternativeProduct(
          name: 'Plant-Based Alternative',
          description: 'Made with plant-based milk alternatives',
          imageUrl: '',
          price: 0.0,
          allergenFree: ['milk', 'dairy'],
        ),
      );
    }

    if (allergenNames.contains('gluten') || allergenNames.contains('wheat')) {
      defaults.add(
        AlternativeProduct(
          name: 'Gluten-Free Version',
          description: 'Made with gluten-free ingredients',
          imageUrl: '',
          price: 0.0,
          allergenFree: ['gluten', 'wheat'],
        ),
      );
    }

    if (allergenNames.contains('egg')) {
      defaults.add(
        AlternativeProduct(
          name: 'Egg-Free Option',
          description: 'Prepared without eggs',
          imageUrl: '',
          price: 0.0,
          allergenFree: ['egg'],
        ),
      );
    }

    // Add a general safe option
    defaults.add(
      AlternativeProduct(
        name: 'Allergen-Safe Version',
        description: 'Specially prepared to avoid detected allergens',
        imageUrl: '',
        price: 0.0,
        allergenFree: allergenNames,
      ),
    );

    return defaults.take(3).toList();
  }

  Future<void> _updateAllergens() async {
    try {
      final response = await _analyzeIngredientsWithAI(currentIngredients);

      if (response != null) {
        List<AllergenInfo> detectedAllergens = [];

        // Parse AI response
        final allergens = response['allergens'] as List<dynamic>? ?? [];

        for (var allergenData in allergens) {
          final allergen = allergenData as Map<String, dynamic>;

          detectedAllergens.add(
            AllergenInfo(
              name: allergen['name'] ?? 'Unknown',
              riskLevel:
                  allergen['severity']?.toString().toLowerCase() ?? 'mild',
              symptoms: List<String>.from(allergen['symptoms'] ?? []),
            ),
          );
        }

        setState(() {
          currentAllergens = detectedAllergens;
        });
      }
    } catch (e) {
      print('Error updating allergens with AI: $e');
      // Fallback to empty list if AI fails
      setState(() {
        currentAllergens = [];
      });
    }
  }

  Future<Map<String, dynamic>?> _analyzeIngredientsWithAI(
    List<String> ingredients,
  ) async {
    try {
      final prompt = '''
Analyze the following food ingredients and identify any potential allergens. Consider both common names and technical/scientific terms (e.g., albumin for egg, casein for milk, etc.).

Ingredients: ${ingredients.join(', ')}

Please provide a JSON response with the following structure:
{
  "allergens": [
    {
      "name": "allergen name",
      "severity": "severe|moderate|mild",
      "symptoms": ["symptom1", "symptom2", "symptom3"],
      "technical_terms": ["term1", "term2"],
      "found_in_ingredients": ["ingredient that contains this allergen"]
    }
  ]
}

Severity levels:
- severe: Life-threatening allergens (peanuts, tree nuts, shellfish, fish, eggs, milk/dairy)
- moderate: Common allergens with significant reactions (wheat/gluten, soy)
- mild: Less severe but notable allergens (sesame, sulfites)

Include technical terms that might be used instead of common names (e.g., albumin, ovalbumin for eggs; casein, whey, lactose for dairy; gluten, wheat protein for wheat).

Only return the JSON object, no additional text.
''';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topK': 1,
          'topP': 1,
          'maxOutputTokens': 2048,
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content != null) {
          // Clean the response to extract JSON
          String cleanedContent = content.toString().trim();
          if (cleanedContent.startsWith('```json')) {
            cleanedContent = cleanedContent.substring(7);
          }
          if (cleanedContent.endsWith('```')) {
            cleanedContent = cleanedContent.substring(
              0,
              cleanedContent.length - 3,
            );
          }

          return json.decode(cleanedContent);
        }
      } else {
        print('AI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error calling AI API: $e');
    }

    return null;
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) {
        String newIngredient = '';
        return AlertDialog(
          title: Text('Add Ingredient'),
          content: TextField(
            onChanged: (value) => newIngredient = value,
            decoration: InputDecoration(
              hintText: 'Enter ingredient name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newIngredient.trim().isNotEmpty) {
                  setState(() {
                    currentIngredients.add(newIngredient.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      currentIngredients.removeAt(index);
    });
  }

  Color _getIngredientColor(String ingredient) {
    // Check if this ingredient is flagged by any allergen
    for (var allergen in currentAllergens) {
      // Check if this ingredient contains allergen terms (including technical terms)
      if (_isIngredientAllergenic(ingredient, allergen)) {
        switch (allergen.riskLevel.toLowerCase()) {
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
    }

    // Safe ingredient (grey)
    return Colors.grey;
  }

  bool _isIngredientAllergenic(String ingredient, AllergenInfo allergen) {
    String lowerIngredient = ingredient.toLowerCase();
    String lowerAllergenName = allergen.name.toLowerCase();

    // Check direct name match
    if (lowerIngredient.contains(lowerAllergenName)) {
      return true;
    }

    // Check common technical terms
    Map<String, List<String>> technicalTerms = {
      'egg': ['albumin', 'ovalbumin', 'ovomucin', 'ovomucoid', 'lysozyme'],
      'milk': ['casein', 'whey', 'lactose', 'lactalbumin', 'lactoglobulin'],
      'dairy': ['casein', 'whey', 'lactose', 'lactalbumin', 'lactoglobulin'],
      'wheat': ['gluten', 'gliadin', 'glutenin', 'wheat protein', 'triticum'],
      'soy': ['lecithin', 'tofu', 'tempeh', 'miso', 'glycine max'],
      'peanut': ['arachis', 'groundnut', 'arachis hypogaea'],
      'shellfish': ['crustacean', 'mollusc', 'chitin'],
      'fish': ['anchovy', 'sardine', 'tuna', 'salmon', 'cod'],
    };

    List<String> terms = technicalTerms[lowerAllergenName] ?? [];
    for (String term in terms) {
      if (lowerIngredient.contains(term)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Result'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ScanHistoryScreen()),
                ),
            child: Image.asset(
              'assets/images/history.png',
              width: 40,
              height: 40,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.image,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dishName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),

                      (currentAllergens.isNotEmpty)
                          ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/emergency.png',
                                  width: 20,
                                  height: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Allergen detected',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/check.png',
                                  width: 20,
                                  height: 20,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'No allergen detected',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FirstAidScreen()),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/first_aid.png',
                                width: 20,
                                height: 20,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Learn about first aid',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: [Tab(text: 'Allergen'), Tab(text: 'Description')],
            labelColor: AppColors.textBlack,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primary,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildAllergenTab(), _buildDescriptionTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allergenic Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isUpdatingAllergens)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          if (currentAllergens.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  currentAllergens.map((allergen) {
                    return SizedBox(
                      width: 100,
                      height: 100,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: allergen.color.withOpacity(0.1),
                          border: Border.all(
                            color: allergen.color.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              allergen.iconPath,
                              width: 32,
                              height: 32,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.warning,
                                  size: 32,
                                  color: allergen.color,
                                );
                              },
                            ),
                            SizedBox(height: 6),
                            Text(
                              allergen.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: allergen.color,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'No Allergens Detected',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'This food appears to be safe',
                    style: TextStyle(color: Colors.green[700], fontSize: 14),
                  ),
                ],
              ),
            ),
          SizedBox(height: 24),
          Text(
            'Alternative Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // REPLACE THE EXISTING ALTERNATIVE PRODUCTS SECTION WITH THIS:
          alternativeProducts.isEmpty
              ? Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Alternative ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Loading...',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              )
              : Column(
                children:
                    alternativeProducts.map((product) {
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.restaurant_menu,
                                color: Colors.green,
                                size: 30,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    product.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (product.allergenFree.isNotEmpty) ...[
                                    SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children:
                                          product.allergenFree.map((allergen) {
                                            return Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green[100],
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${allergen.capitalize()}-free',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scanned Ingredients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _toggleEdit,
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isEditing
                            ? Colors.red[50]
                            : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEditing ? Icons.close : Icons.edit,
                    color: isEditing ? Colors.red : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            width: 400,
            height: 100,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color Legend:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildColorLegendItem(Colors.grey, 'Safe'),
                      SizedBox(width: 20),
                      _buildColorLegendItem(Colors.green, 'Mild'),
                      SizedBox(width: 20),
                      _buildColorLegendItem(Colors.orange, 'Moderate'),
                      SizedBox(width: 20),
                      _buildColorLegendItem(Colors.red, 'Severe'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredients (${currentIngredients.length}):',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textBlack,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int i = 0; i < currentIngredients.length; i++)
                      _buildIngredientChip(currentIngredients[i], i),

                    // Add button
                    if (isEditing)
                      GestureDetector(
                        onTap: _addIngredient,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isEditing) ...[
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIngredientChip(String ingredient, int index) {
    Color chipColor = _getIngredientColor(ingredient);
    bool isSafe = chipColor == Colors.grey;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (context) => DraggableScrollableSheet(
                expand: false,
                builder:
                    (_, controller) => SingleChildScrollView(
                      controller: controller,
                      child: IngredientAllergenModal(ingredient: ingredient),
                    ),
              ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSafe ? chipColor.withOpacity(0.15) : chipColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSafe
                    ? chipColor.withOpacity(0.4)
                    : chipColor.withOpacity(0.8),
            width: isSafe ? 1.5 : 0,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isEditing ? 10 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ingredient,
                style: TextStyle(
                  fontSize: 13,
                  color: isSafe ? Colors.black87 : Colors.white,
                  fontWeight: isSafe ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
              if (!isEditing) ...[
                SizedBox(width: 6),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isSafe ? Colors.black54 : Colors.white70,
                ),
              ],
              if (isEditing) ...[
                SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _removeIngredient(index),
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          isSafe
                              ? Colors.black.withOpacity(0.1)
                              : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: isSafe ? Colors.black54 : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorLegendItem(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

// Extension to capitalize first letter
extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}

class AlternativeProduct {
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final List<String> allergenFree;

  AlternativeProduct({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.allergenFree,
  });
}
