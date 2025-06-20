import 'package:allergen/screens/homescreen.dart';
import 'package:allergen/screens/profile_details.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String username = '';
  Set<String> selectedAllergens = {};
  Map<String, double> allergenSeverity = {};
  TextEditingController searchController = TextEditingController();
  List<String> filteredAllergens = [];
  List<String> fdaIngredients = [];
  bool isSearchingFDA = false;
  List<String> savedAllergens = [];

  // Keep some common allergens as fallback
  final List<String> commonAllergens = [
    'Shellfish',
    'Sesame',
    'Egg',
    'Peanut',
    'Fish',
    'Milk',
    'Soybean',
    'Shrimp',
    'Nuts',
    'Wheat',
  ];

  // FDA major allergens as defined by FALCPA
  final List<String> fdaMajorAllergens = [
    'Milk',
    'Eggs',
    'Fish',
    'Crustacean shellfish',
    'Tree nuts',
    'Peanuts',
    'Wheat',
    'Soybeans',
    'Sesame',
  ];

  @override
  void initState() {
    super.initState();
    filteredAllergens = List.from(commonAllergens);
    fetchUsername();
    loadExistingAllergens();
    searchController.addListener(_onSearchChanged);
    
  }

  List<String> _getAllAllergens() {
    Set<String> allAllergens = {};
    allAllergens.addAll(commonAllergens);
    allAllergens.addAll(savedAllergens);
    return allAllergens.toList();
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    searchController.clear();
   
  }

  void _onSearchChanged() {
    String searchTerm = searchController.text.trim();

    if (searchTerm.isEmpty) {
      setState(() {
        _updateFilteredAllergens();
        isSearchingFDA = false;
      });
    } else if (searchTerm.length >= 2) {
      _searchFDAIngredients(searchTerm);
    } else {
      setState(() {
        filteredAllergens =
            commonAllergens
                .where(
                  (allergen) =>
                      allergen.toLowerCase().contains(searchTerm.toLowerCase()),
                )
                .toList();
        isSearchingFDA = false;
      });
    }
  }

  void _updateFilteredAllergens() {
    filteredAllergens = _getAllAllergens();
  }

  Future<void> _searchFDAIngredients(String searchTerm) async {
    setState(() {
      isSearchingFDA = true;
    });

    try {
      // Search FDA drug labels for ingredients and active ingredients
      List<String> searchFields = [
        'active_ingredient',
        'inactive_ingredient',
        'substance_name',
        'openfda.substance_name',
        'openfda.generic_name',
      ];

      Set<String> foundIngredients = {};

      // Search multiple fields for comprehensive results
      for (String field in searchFields) {
        try {
          final response = await http.get(
            Uri.parse(
              'https://api.fda.gov/drug/label.json?search=$field:"$searchTerm"&limit=50',
            ),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            if (data['results'] != null) {
              for (var result in data['results']) {
                // Extract ingredients from various fields
                _extractIngredientsFromResult(
                  result,
                  searchTerm,
                  foundIngredients,
                );
              }
            }
          }
        } catch (e) {
          print('Error searching $field: $e');
          continue;
        }
      }

      // Also search for partial matches in ingredient lists
      try {
        final broadResponse = await http.get(
          Uri.parse(
            'https://api.fda.gov/drug/label.json?search=active_ingredient:*$searchTerm*+OR+inactive_ingredient:*$searchTerm*&limit=30',
          ),
        );

        if (broadResponse.statusCode == 200) {
          final broadData = json.decode(broadResponse.body);
          if (broadData['results'] != null) {
            for (var result in broadData['results']) {
              _extractIngredientsFromResult(
                result,
                searchTerm,
                foundIngredients,
              );
            }
          }
        }
      } catch (e) {
        print('Error in broad search: $e');
      }

      // Add major FDA allergens that match search
      for (String allergen in fdaMajorAllergens) {
        if (allergen.toLowerCase().contains(searchTerm.toLowerCase())) {
          foundIngredients.add(allergen);
        }
      }

      setState(() {
        fdaIngredients = foundIngredients.toList();

        // Combine common allergens with FDA results for filtered list
        Set<String> combinedAllergens = {};

        // Add matching common allergens
        combinedAllergens.addAll(
          commonAllergens.where(
            (allergen) =>
                allergen.toLowerCase().contains(searchTerm.toLowerCase()),
          ),
        );

        // Add FDA ingredients
        combinedAllergens.addAll(fdaIngredients);

        filteredAllergens = combinedAllergens.toList();
        isSearchingFDA = false;
      });
    } catch (e) {
      print('Error searching FDA: $e');
      // Fallback to local search
      setState(() {
        filteredAllergens =
            commonAllergens
                .where(
                  (allergen) =>
                      allergen.toLowerCase().contains(searchTerm.toLowerCase()),
                )
                .toList();
        isSearchingFDA = false;
      });
    }
  }

  void _extractIngredientsFromResult(
    Map<String, dynamic> result,
    String searchTerm,
    Set<String> foundIngredients,
  ) {
    // Extract from active_ingredient
    if (result['active_ingredient'] != null) {
      for (var ingredient in result['active_ingredient']) {
        String ingredientName = '';
        if (ingredient is String) {
          ingredientName = ingredient;
        } else if (ingredient is Map && ingredient['name'] != null) {
          ingredientName = ingredient['name'].toString();
        }

        if (ingredientName.isNotEmpty) {
          List<String> extracted = _extractPotentialAllergens(
            ingredientName,
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }
    }

    // Extract from inactive_ingredient
    if (result['inactive_ingredient'] != null) {
      for (var ingredient in result['inactive_ingredient']) {
        String ingredientName = ingredient.toString();
        if (ingredientName.isNotEmpty) {
          List<String> extracted = _extractPotentialAllergens(
            ingredientName,
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }
    }

    // Extract from openfda fields
    if (result['openfda'] != null) {
      var openfda = result['openfda'];

      if (openfda['substance_name'] != null) {
        for (var substance in openfda['substance_name']) {
          List<String> extracted = _extractPotentialAllergens(
            substance.toString(),
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }

      if (openfda['generic_name'] != null) {
        for (var name in openfda['generic_name']) {
          List<String> extracted = _extractPotentialAllergens(
            name.toString(),
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }
    }
  }

  List<String> _extractPotentialAllergens(String text, String searchTerm) {
    List<String> allergens = [];
    String lowerText = text.toLowerCase();
    String lowerSearchTerm = searchTerm.toLowerCase();

    // If the text contains the search term, process it
    if (lowerText.contains(lowerSearchTerm)) {
      // Clean and format the ingredient name
      String cleanedText = _cleanIngredientName(text);

      if (cleanedText.isNotEmpty && cleanedText.length <= 50) {
        // Reasonable length limit
        allergens.add(cleanedText);
      }

      // Also extract individual words that contain the search term
      List<String> words = text.split(RegExp(r'[,;()\[\]\s]+'));
      for (String word in words) {
        String cleanWord = _cleanIngredientName(word);
        if (cleanWord.toLowerCase().contains(lowerSearchTerm) &&
            cleanWord.length >= 3 &&
            cleanWord.length <= 30) {
          allergens.add(cleanWord);
        }
      }
    }

    return allergens;
  }

  String _cleanIngredientName(String text) {
    // Remove common pharmaceutical suffixes and prefixes
    String cleaned =
        text
            .replaceAll(
              RegExp(
                r'\b(hydrochloride|hcl|sulfate|sodium|mg|mcg|iu)\b',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(
              RegExp(r'[^\w\s-]'),
              '',
            ) // Remove special chars except hyphens
            .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
            .trim();

    // Capitalize first letter of each word
    return cleaned
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : '',
        )
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  Future<void> fetchUsername() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
      setState(() {
        username = 'User';
      });
    }
  }

  Future<void> loadExistingAllergens() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot profileSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        setState(() {
          selectedAllergens.clear();
          allergenSeverity.clear();
          savedAllergens.clear();

          for (QueryDocumentSnapshot doc in profileSnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String allergenName = data['name'] ?? '';
            double severity = (data['severity'] ?? 0.5).toDouble();

            if (allergenName.isNotEmpty) {
              selectedAllergens.add(allergenName);
              allergenSeverity[allergenName] = severity;
              savedAllergens.add(allergenName);
            }
          }
          _updateFilteredAllergens();
        });
      }
    } catch (e) {
      print('Error loading existing allergens: $e');
    }
  }

  Future<void> deleteAllergen(String allergen) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot docs =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergen)
                .get();

        for (QueryDocumentSnapshot doc in docs.docs) {
          await doc.reference.delete();
        }

        setState(() {
          selectedAllergens.remove(allergen);
          allergenSeverity.remove(allergen);
          savedAllergens.remove(allergen);
          _updateFilteredAllergens();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$allergen deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting allergen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleAllergen(String allergen) {
    setState(() {
      if (selectedAllergens.contains(allergen)) {
        selectedAllergens.remove(allergen);
        allergenSeverity.remove(allergen);
      } else {
        selectedAllergens.add(allergen);
        allergenSeverity[allergen] = 0.5; // Default to moderate
      }
    });
  }

  Color _getSeverityColor(double severity) {
    if (severity < 0.33) return Colors.green.shade300; // Mild
    if (severity < 0.67) return Colors.orange.shade300; // Moderate
    return Colors.red.shade300; // Severe
  }

  void showAllergenModal(String allergen, {bool isManualAdd = false}) {
    double currentSeverity = allergenSeverity[allergen] ?? 0.5;
    TextEditingController manualAllergenController = TextEditingController();
    if (isManualAdd) manualAllergenController.text = allergen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isManualAdd) ...[
                        Text(
                          'Manually add your allergen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: manualAllergenController,
                          decoration: InputDecoration(
                            hintText: 'Enter allergen name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Text(
                              allergen,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            if (selectedAllergens.contains(allergen))
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  Navigator.pop(context);
                                  deleteAllergen(allergen);
                                },
                              ),
                          ],
                        ),
                      ],
                      SizedBox(height: 24),
                      Text(
                        'How severe is this allergen reaction?',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 24),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8,
                          activeTrackColor: _getSliderColor(currentSeverity),
                          thumbColor: _getSliderColor(currentSeverity),
                        ),
                        child: Slider(
                          value: currentSeverity,
                          onChanged:
                              (value) =>
                                  setModalState(() => currentSeverity = value),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mild',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Moderate',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Severe',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            String finalAllergen =
                                isManualAdd
                                    ? manualAllergenController.text.trim()
                                    : allergen;
                            if (finalAllergen.isNotEmpty) {
                              setState(() {
                                selectedAllergens.add(finalAllergen);
                                allergenSeverity[finalAllergen] =
                                    currentSeverity;
                                if (!savedAllergens.contains(finalAllergen)) {
                                  savedAllergens.add(finalAllergen);
                                }
                                _updateFilteredAllergens();
                              });
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0891B2),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isManualAdd ? 'Save Allergen' : 'Save Selection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Color _getSliderColor(double value) {
    if (value < 0.33) return Colors.green;
    if (value < 0.67) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Back',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome ${username.isNotEmpty ? username : 'User'}!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search for allergens and drug ingredients',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            // Search Bar with Clear Button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon:
                      isSearchingFDA
                          ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0891B2),
                                ),
                              ),
                            ),
                          )
                          : Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon:
                      searchController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: _clearSearch,
                            tooltip: 'Clear search',
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            // Allergen Tiles
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      filteredAllergens.map((allergen) {
                        bool isSelected = selectedAllergens.contains(allergen);
                        bool isFromFDA = fdaIngredients.contains(allergen);
                        bool isSaved = savedAllergens.contains(allergen);
                        Color chipColor =
                            isSelected
                                ? _getSeverityColor(
                                  allergenSeverity[allergen] ?? 0.5,
                                )
                                : Colors.grey.shade200;

                        return GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              showAllergenModal(allergen);
                            } else {
                              toggleAllergen(allergen);
                              showAllergenModal(allergen);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.green,
                                        width: 2,
                                      )
                                      : isFromFDA
                                      ? Border.all(
                                        color: Color(0xFF0891B2),
                                        width: 1,
                                      )
                                      : isSaved
                                      ? Border.all(
                                        color: Colors.purple,
                                        width: 1,
                                      )
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8),
                                ],
                                if (isFromFDA && !isSelected) ...[
                                  Icon(
                                    Icons.medication,
                                    size: 14,
                                    color: Color(0xFF0891B2),
                                  ),
                                  SizedBox(width: 6),
                                ],
                                if (isSaved && !isSelected && !isFromFDA) ...[
                                  Icon(
                                    Icons.bookmark,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    allergen,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showAllergenModal('', isManualAdd: true),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF0891B2)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Add manually',
                      style: TextStyle(
                        color: Color(0xFF0891B2),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          WriteBatch batch = FirebaseFirestore.instance.batch();
                          CollectionReference profileRef = FirebaseFirestore
                              .instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('profile');

                          QuerySnapshot existingAllergens =
                              await profileRef
                                  .where('type', isEqualTo: 'allergen')
                                  .get();
                          for (QueryDocumentSnapshot doc
                              in existingAllergens.docs) {
                            batch.delete(doc.reference);
                          }

                          for (String allergen in selectedAllergens) {
                            DocumentReference allergenDoc = profileRef.doc();
                            batch.set(allergenDoc, {
                              'name': allergen,
                              'severity': allergenSeverity[allergen] ?? 0.5,
                              'createdAt': FieldValue.serverTimestamp(),
                              'type': 'allergen',
                              'source':
                                  fdaIngredients.contains(allergen)
                                      ? 'FDA_DRUG'
                                      : 'manual',
                            });
                          }

                          await batch.commit();
                         Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => ProfileDetailsScreen()),
);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Allergens saved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving allergens: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0891B2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
