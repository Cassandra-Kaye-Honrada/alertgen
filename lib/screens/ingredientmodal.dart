import 'dart:convert';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:allergen/screens/scan_screen.dart';

class IngredientAllergenModal extends StatefulWidget {
  final String ingredient;
  final List<AllergenInfo> availableAllergens;

  const IngredientAllergenModal({
    Key? key,
    required this.ingredient,
    required this.availableAllergens,
  }) : super(key: key);

  @override
  State<IngredientAllergenModal> createState() =>
      IngredientAllergenModalState();
}

class IngredientAllergenModalState extends State<IngredientAllergenModal> {
  bool isLoading = true;
  List<AllergenInfo> allergensFound = [];
  String? errorMessage;
  String detectionMethod = 'USDA Database';

  final usdaApiKey = 'CKNlV96OlhW76cXyo151cbnEKe0e6P2Up85QVlTs';

  @override
  void initState() {
    super.initState();
    findAllergens();
  }

  AllergenInfo? findMatchingAllergen(String detectedAllergen) {
    String detected = detectedAllergen.toLowerCase();

    for (AllergenInfo allergen in widget.availableAllergens) {
      String allergenName = allergen.name.toLowerCase();

      if (detected == allergenName || isAllergenMatch(detected, allergenName)) {
        return allergen;
      }
    }
    return null;
  }

  bool isAllergenMatch(String detected, String available) {
    Map<String, List<String>> variations = {
      'milk': ['dairy', 'milk'],
      'dairy': ['milk', 'dairy'],
      'egg': ['eggs', 'egg'],
      'eggs': ['egg', 'eggs'],
      'wheat': ['wheat', 'gluten'],
      'gluten': ['wheat', 'gluten'],
      'soy': ['soy', 'soya', 'soybeans'],
      'peanut': ['peanuts', 'peanut', 'groundnut'],
      'peanuts': ['peanut', 'peanuts', 'groundnut'],
      'fish': ['fish'],
      'shellfish': ['shellfish', 'seafood'],
      'tree nuts': ['tree nut', 'tree nuts', 'nuts'],
      'nuts': ['tree nuts', 'tree nut', 'nuts'],
      'sesame': ['sesame'],
    };

    List<String> matches = variations[available] ?? [available];
    return matches.contains(detected);
  }

  Future<void> findAllergens() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final result = await searchUSDADatabase(widget.ingredient);

      if (result['found'] == true) {
        final detectedNames = findAllergensInData(result['data']);
        List<AllergenInfo> foundAllergens = [];

        for (String name in detectedNames) {
          AllergenInfo? match = findMatchingAllergen(name);
          if (match != null && !foundAllergens.contains(match)) {
            foundAllergens.add(match);
          }
        }

        setState(() {
          allergensFound = foundAllergens;
          detectionMethod = 'USDA Database';
          isLoading = false;
        });
      } else {
        setState(() {
          allergensFound = [];
          detectionMethod = 'No allergens detected';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Unable to check ingredient. Please try again.';
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> searchUSDADatabase(String ingredient) async {
    try {
      List<String> searchTerms = createSearchTerms(ingredient);

      for (String term in searchTerms) {
        final url =
            'https://api.nal.usda.gov/fdc/v1/foods/search?query=${Uri.encodeComponent(term)}&api_key=$usdaApiKey&pageSize=5';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final foods = data['foods'] as List<dynamic>;

          if (foods.isNotEmpty) {
            List<String> foodInfo = [];
            for (var food in foods) {
              final description = food['description']?.toString() ?? '';
              final ingredients = food['ingredients']?.toString() ?? '';

              String info = description;
              if (ingredients.isNotEmpty) {
                info += ' ingredients: $ingredients';
              }
              foodInfo.add(info);
            }

            return {'found': true, 'data': foodInfo.join(' ')};
          }
        }
      }
      return {'found': false};
    } catch (e) {
      return {'found': false};
    }
  }

  List<String> createSearchTerms(String ingredient) {
    List<String> terms = [ingredient, ingredient.toLowerCase()];

    if (ingredient.contains(' ')) {
      List<String> words = ingredient.split(' ');
      for (String word in words) {
        if (word.length >= 3) terms.add(word);
      }
    }

    String simplified = ingredient.toLowerCase();
    List<String> removeWords = [
      'fried',
      'cooked',
      'fresh',
      'raw',
      'organic',
      'with',
    ];
    for (String word in removeWords) {
      simplified = simplified.replaceAll(word, ' ').trim();
    }
    if (simplified.isNotEmpty) terms.add(simplified);

    return terms.toSet().where((term) => term.length >= 3).toList();
  }

  List<String> findAllergensInData(String data) {
    List<String> found = [];
    String dataLower = data.toLowerCase();

    Map<String, List<String>> allergenKeywords = {
      'milk': ['milk', 'dairy', 'cheese', 'butter', 'cream', 'whey', 'yogurt'],
      'egg': ['egg', 'albumin', 'mayonnaise'],
      'fish': ['fish', 'salmon', 'tuna', 'cod', 'anchovy'],
      'shellfish': ['shrimp', 'crab', 'lobster', 'oyster', 'shellfish'],
      'tree nuts': [
        'almond',
        'walnut',
        'cashew',
        'pecan',
        'hazelnut',
        'pistachio',
      ],
      'peanuts': ['peanut', 'groundnut'],
      'wheat': ['wheat', 'flour', 'gluten', 'bread'],
      'soy': ['soy', 'tofu', 'soybean'],
      'sesame': ['sesame', 'tahini'],
    };

    for (String allergen in allergenKeywords.keys) {
      for (String keyword in allergenKeywords[allergen]!) {
        if (dataLower.contains(keyword)) {
          if (!found.contains(allergen)) found.add(allergen);
          break;
        }
      }
    }
    return found;
  }

  Widget getAllergenIcon(AllergenInfo allergen) {
    String? imagePath;
    switch (allergen.name.toLowerCase()) {
      case 'milk':
      case 'dairy':
        imagePath = 'assets/allergens/Milk.png';
        break;
      case 'egg':
      case 'eggs':
        imagePath = 'assets/allergens/Eggs.png';
        break;
      case 'peanut':
      case 'peanuts':
        imagePath = 'assets/allergens/Nuts.png';
        break;
      case 'tree nuts':
      case 'nuts':
        imagePath = 'assets/allergens/Cashew.png';
        break;
      case 'soy':
        imagePath = 'assets/allergens/Soy Bean.png';
        break;
      case 'wheat':
      case 'gluten':
        imagePath = 'assets/allergens/Gluten.png';
        break;
      case 'fish':
        imagePath = 'assets/allergens/Fish.png';
        break;
      case 'shellfish':
        imagePath = 'assets/allergens/Crab.png';
        break;
      case 'sesame':
        imagePath = 'assets/allergens/Sesame.png';
        break;
      default:
        return const Icon(Icons.warning, color: Colors.orange, size: 30);
    }

    return Image.asset(imagePath!, width: 30, height: 30);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              const Text(
                'About the ingredient',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: findAllergens,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              widget.ingredient,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            if (allergensFound.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(
                  'Contains allergens',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children:
                    allergensFound.map((allergen) {
                      return Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.15),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(child: getAllergenIcon(allergen)),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 70,
                            child: Text(
                              allergen.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'No allergens found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}
