import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:allergen/styleguide.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AllergenProfileScreen extends StatefulWidget {
  const AllergenProfileScreen({Key? key}) : super(key: key);

  @override
  State<AllergenProfileScreen> createState() => _AllergenProfileScreenState();
}

class _AllergenProfileScreenState extends State<AllergenProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  Set<String> selectedAllergens = {};
  Map<String, double> allergenSeverity = {};
  List<String> filteredAllergens = [];
  List<String> fdaIngredients = [];
  List<String> savedAllergens = [];
  bool isLoading = true;
  bool isSearchingFDA = false;
  bool isGeneralProductAllergensEnabled = true;

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
    _loadUserAllergens();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getAllAllergens() {
    Set<String> allAllergens = {};
    allAllergens.addAll(commonAllergens);
    allAllergens.addAll(savedAllergens);
    return allAllergens.toList();
  }

  void _clearSearch() {
    _searchController.clear();
  }

  void _onSearchChanged() {
    String searchTerm = _searchController.text.trim();

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
            _getAllAllergens()
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

        // Add matching saved/common allergens
        combinedAllergens.addAll(
          _getAllAllergens().where(
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
            _getAllAllergens()
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

  Future<void> _loadUserAllergens() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot snapshot =
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

          for (QueryDocumentSnapshot doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String allergenName = data['name'] ?? '';
            double severity = (data['severity'] ?? 0.5).toDouble();

            if (allergenName.isNotEmpty) {
              selectedAllergens.add(allergenName);
              allergenSeverity[allergenName] = severity;
              savedAllergens.add(allergenName);

              if (!commonAllergens.contains(allergenName)) {
                commonAllergens.add(allergenName);
              }
            }
          }
          _updateFilteredAllergens();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user allergens: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void toggleAllergen(String allergen) {
    setState(() {
      if (selectedAllergens.contains(allergen)) {
        selectedAllergens.remove(allergen);
        allergenSeverity.remove(allergen);
      } else {
        selectedAllergens.add(allergen);
        allergenSeverity[allergen] = 0.5;
      }
    });
  }

  Color _getSeverityColor(double severity) {
    if (severity < 0.33) return const Color(0xFF10B981); // Green
    if (severity < 0.67) return const Color(0xFFF59E0B); // Orange
    return const Color(0xFFEF4444); // Red
  }

  String _getSeverityLabel(double severity) {
    if (severity < 0.33) return 'Mild';
    if (severity < 0.67) return 'Moderate';
    return 'Severe';
  }

  void showAllergenModal(String allergen, {bool isManualAdd = false}) {
    double currentSeverity = allergenSeverity[allergen] ?? 0.5;
    TextEditingController manualAllergenController = TextEditingController();

    if (isManualAdd) {
      manualAllergenController.text = allergen;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
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
                        const Text(
                          'Manually add your allergen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: manualAllergenController,
                          decoration: InputDecoration(
                            hintText: 'Enter allergen name',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontFamily: 'Poppins',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor3,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Row(
                          children: [
                            Text(
                              allergen,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      const Text(
                        'How severe is this allergen reaction?',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 20,
                                ),
                                activeTrackColor: _getSeverityColor(
                                  currentSeverity,
                                ),
                                inactiveTrackColor: Colors.grey.shade300,
                                thumbColor: _getSeverityColor(currentSeverity),
                                overlayColor: _getSeverityColor(
                                  currentSeverity,
                                ).withOpacity(0.2),
                              ),
                              child: Slider(
                                value: currentSeverity,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (value) {
                                  setModalState(() {
                                    currentSeverity = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mild',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  'Moderate',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  'Severe',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Drag to edit',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalAllergen =
                                isManualAdd
                                    ? manualAllergenController.text.trim()
                                    : allergen;

                            if (finalAllergen.isNotEmpty) {
                              setState(() {
                                selectedAllergens.add(finalAllergen);
                                allergenSeverity[finalAllergen] =
                                    currentSeverity;

                                if (isManualAdd &&
                                    !savedAllergens.contains(finalAllergen)) {
                                  savedAllergens.add(finalAllergen);
                                }
                                if (!commonAllergens.contains(finalAllergen)) {
                                  commonAllergens.add(finalAllergen);
                                }
                                _updateFilteredAllergens();
                              });

                              await _saveAllergenToFirebase(
                                finalAllergen,
                                currentSeverity,
                              );
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor3,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            isManualAdd
                                ? 'Add Allergen'
                                : selectedAllergens.contains(allergen)
                                ? 'Update Severity'
                                : 'Add Allergen',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
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

  Future<void> _saveAllergenToFirebase(
    String allergenName,
    double severity,
  ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot existingAllergen =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergenName)
                .get();

        if (existingAllergen.docs.isNotEmpty) {
          await existingAllergen.docs.first.reference.update({
            'severity': severity,
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .add({
                'name': allergenName,
                'severity': severity,
                'type': 'allergen',
                'createdAt': FieldValue.serverTimestamp(),
                'source':
                    fdaIngredients.contains(allergenName)
                        ? 'FDA_DRUG'
                        : 'manual',
              });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$allergenName saved successfully!',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.primaryColor3,
          ),
        );
      }
    } catch (e) {
      print('Error saving allergen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error saving allergen. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRemoveConfirmation(String allergenName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Allergen',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          content: Text(
            'Are you sure you want to remove "$allergenName" from your allergen profile?',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAllergen(allergenName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeAllergen(String allergenName) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenDocs =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergenName)
                .get();

        for (QueryDocumentSnapshot doc in allergenDocs.docs) {
          await doc.reference.delete();
        }

        setState(() {
          selectedAllergens.remove(allergenName);
          allergenSeverity.remove(allergenName);
          savedAllergens.remove(allergenName);
          _updateFilteredAllergens();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allergen removed from your profile',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Color(0xFF0EA5E9),
          ),
        );
      }
    } catch (e) {
      print('Error removing allergen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error removing allergen. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Allergen Profile',
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // General Product Allergens Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Product Allergens',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enable the filter to view all allergens including those affecting you.',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isGeneralProductAllergensEnabled,
                  onChanged: (value) {
                    setState(() {
                      isGeneralProductAllergensEnabled = value;
                    });
                  },
                  activeColor: const Color(0xFF0EA5E9),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Title and Search Bar
          const Text(
            'Search for allergens and drug ingredients',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon:
                    isSearchingFDA
                        ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor3,
                              ),
                            ),
                          ),
                        )
                        : const Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Color(0xFF9CA3AF),
                          ),
                          onPressed: _clearSearch,
                          tooltip: 'Clear search',
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showAllergenModal('', isManualAdd: true),
              child: const Text(
                'Not here? Manually add',
                style: TextStyle(
                  color: Color(0xFF0EA5E9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),

          // Available Allergens (Search Results)
          if (_searchController.text.isNotEmpty &&
              filteredAllergens.isNotEmpty) ...[
            const Text(
              'Available Allergens',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredAllergens.length,
              itemBuilder: (context, index) {
                final allergen = filteredAllergens[index];
                final isSelected = selectedAllergens.contains(allergen);
                final isFromFDA = fdaIngredients.contains(allergen);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primaryColor3
                              : const Color(0xFFE5E7EB),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showAllergenModal(allergen),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    allergen,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                      color:
                                          isSelected
                                              ? AppColors.primaryColor3
                                              : const Color(0xFF374151),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getSeverityColor(
                                          allergenSeverity[allergen] ?? 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getSeverityLabel(
                                          allergenSeverity[allergen] ?? 0.5,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color:
                                  isSelected
                                      ? AppColors.primaryColor3
                                      : const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),

          // Active Allergens
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            )
          else if (selectedAllergens.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No allergens added yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add allergens to help us recommend better products for you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'Your Allergens',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            ...selectedAllergens.map((allergen) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showAllergenModal(allergen),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allergen,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(
                                      allergenSeverity[allergen] ?? 0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _getSeverityLabel(
                                      allergenSeverity[allergen] ?? 0.5,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showRemoveConfirmation(allergen),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
