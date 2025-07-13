import 'dart:io';
import 'dart:ui';
import 'package:allergen/screens/profile_screen_items/scanHistoryScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/screens/allergen_tab.dart';
import 'package:allergen/screens/description_tab.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ResultScreen extends StatefulWidget {
  final File? image;
  final String dishName;
  final String description;
  final List<String> ingredients;
  final List<AllergenInfo> allergens;
  final Function(List<String>) onIngredientsChanged;
  final bool isOCRAnalysis;

  const ResultScreen({
    Key? key,
    required this.image,
    required this.dishName,
    required this.description,
    required this.ingredients,
    required this.allergens,
    required this.onIngredientsChanged,
    required this.isOCRAnalysis,
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
  String? documentId;

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
      await _updateAllergens();
      await _updateInFirebase();
      await widget.onIngredientsChanged(currentIngredients);
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

  Future<void> _updateInFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
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

  Future<void> _updateAllergens() async {
    try {
      final response = await _analyzeIngredientsWithAI(currentIngredients);
      if (response != null) {
        List<AllergenInfo> detectedAllergens = [];
        final allergens = response['allergens'] as List<dynamic>? ?? [];
        for (var allergenData in allergens) {
          final allergen = allergenData as Map<String, dynamic>;
          detectedAllergens.add(
            AllergenInfo(
              name: allergen['name'] ?? 'Unknown',
              riskLevel:
                  allergen['severity']?.toString().toLowerCase() ?? 'mild',
              symptoms: List<String>.from(allergen['symptoms'] ?? []),
              source: allergen['source'] ?? '',
            ),
          );
        }
        setState(() {
          currentAllergens = detectedAllergens;
        });
      }
    } catch (e) {
      print('Error updating allergens with AI: $e');
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
                if (widget.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      widget.image!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo, size: 40, color: Colors.grey),
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
              children: [
                AllergenTab(
                  currentAllergens: currentAllergens,
                  isUpdatingAllergens: isUpdatingAllergens,
                  productName: widget.dishName,
                  isOCRAnalysis: widget.isOCRAnalysis,
                ),
                DescriptionTab(
                  description: widget.description,
                  currentIngredients: currentIngredients,
                  currentAllergens: currentAllergens,
                  isEditing: isEditing,
                  toggleEdit: _toggleEdit,
                  addIngredient: _addIngredient,
                  removeIngredient: _removeIngredient,
                  saveChanges: _saveChanges,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
