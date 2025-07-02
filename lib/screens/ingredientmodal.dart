import 'dart:convert';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class IngredientAllergenModal extends StatefulWidget {
  final String ingredient;

  const IngredientAllergenModal({Key? key, required this.ingredient})
    : super(key: key);

  @override
  State<IngredientAllergenModal> createState() =>
      IngredientAllergenModalState();
}

class IngredientAllergenModalState extends State<IngredientAllergenModal> {
  bool isLoading = true;
  String simplifiedIngredient = '';
  List<String> allergensFound = [];
  String riskLevel = 'Unknown';
  String? errorMessage;

  final geminiApiKey = 'AIzaSyCzyd0ukiEilgPiJ29HNplB2UtWyOKCZkA';
  final usdaApiKey = 'CKNlV96OlhW76cXyo151cbnEKe0e6P2Up85QVlTs';

  @override
  void initState() {
    super.initState();
    analyzeIngredient();
  }

  Future<void> analyzeIngredient() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final localAllergens = detectLocalAllergens(widget.ingredient);

      if (localAllergens.isNotEmpty) {
        setState(() {
          allergensFound = localAllergens;
          riskLevel = 'Contains allergen';
          isLoading = false;
        });
      } else {
        simplifiedIngredient = await getSimplifiedIngredient(widget.ingredient);
        final usdaAllergens = await getAllergenInfoFromUSDA(
          simplifiedIngredient,
        );

        setState(() {
          allergensFound = usdaAllergens['allergens'] ?? [];
          riskLevel = usdaAllergens['risk'] ?? 'Unknown';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  List<String> detectLocalAllergens(String ingredient) {
    String lowerIngredient = ingredient.toLowerCase();
    List<String> foundAllergens = [];

    Map<String, List<String>> allergenTerms = {
      'Egg': [
        'egg',
        'eggs',
        'albumin',
        'ovalbumin',
        'ovomucin',
        'ovomucoid',
        'lysozyme',
        'lecithin',
        'mayonnaise',
        'meringue',
        'custard',
      ],
      'Milk': [
        'milk',
        'dairy',
        'casein',
        'whey',
        'lactose',
        'lactalbumin',
        'lactoglobulin',
        'cheese',
        'butter',
        'cream',
        'yogurt',
      ],
      'Wheat': [
        'wheat',
        'gluten',
        'gliadin',
        'glutenin',
        'flour',
        'bread',
        'pasta',
        'noodle',
        'wrapper',
        'triticum',
      ],
      'Soy': [
        'soy',
        'soya',
        'lecithin',
        'tofu',
        'tempeh',
        'miso',
        'glycine max',
        'soybean',
        'edamame',
      ],
      'Peanut': ['peanut', 'groundnut', 'arachis', 'arachis hypogaea'],
      'Tree nut': [
        'almond',
        'cashew',
        'walnut',
        'pecan',
        'pistachio',
        'hazelnut',
        'macadamia',
        'brazil nut',
        'pine nut',
      ],
      'Fish': [
        'fish',
        'anchovy',
        'sardine',
        'tuna',
        'salmon',
        'cod',
        'mackerel',
      ],
      'Shellfish': [
        'shellfish',
        'shrimp',
        'crab',
        'lobster',
        'crayfish',
        'crustacean',
        'mollusc',
        'oyster',
        'clam',
        'mussel',
        'scallop',
        'chitin',
      ],
      'Sesame': ['sesame', 'tahini', 'sesamum'],
    };

    for (var allergen in allergenTerms.keys) {
      for (var term in allergenTerms[allergen]!) {
        if (lowerIngredient.contains(term)) {
          foundAllergens.add(allergen);
          break;
        }
      }
    }

    return foundAllergens;
  }

  Future<String> getSimplifiedIngredient(String rawIngredient) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: geminiApiKey,
    );

    final prompt =
        "Simplify or generalize this technical ingredient into a common food name. "
        "Example: 'sodium caseinate' -> 'milk protein'. Now simplify: '$rawIngredient'";

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? rawIngredient;
  }

  Future<Map<String, dynamic>> getAllergenInfoFromUSDA(
    String ingredient,
  ) async {
    final url =
        'https://api.nal.usda.gov/fdc/v1/foods/search?query=$ingredient&api_key=$usdaApiKey&pageSize=1';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch data from USDA');
    }

    final data = json.decode(response.body);
    final foods = data['foods'] as List<dynamic>;

    if (foods.isEmpty) {
      return {'allergens': <String>[], 'risk': 'Safe'};
    }

    final description = foods.first['description'].toString().toLowerCase();

    const knownAllergens = [
      'milk',
      'egg',
      'peanut',
      'soy',
      'wheat',
      'tree nut',
      'shellfish',
      'fish',
      'oat',
      'sesame',
    ];

    List<String> foundAllergens = [];
    for (var allergen in knownAllergens) {
      if (description.contains(allergen)) {
        foundAllergens.add(allergen[0].toUpperCase() + allergen.substring(1));
      }
    }

    return {
      'allergens': foundAllergens,
      'risk': foundAllergens.isNotEmpty ? 'Contains allergen' : 'Safe',
    };
  }

  Widget getAllergenImage(String allergen) {
    String? assetName;
    switch (allergen.toLowerCase()) {
      case 'milk':
        assetName = 'assets/allergens/Milk.png';
        break;
      case 'egg':
        assetName = 'assets/allergens/Eggs.png';
        break;
      case 'peanut':
        assetName = 'assets/allergens/Nuts.png';
        break;
      case 'tree nut':
        assetName = 'assets/allergens/Cashew.png';
        break;
      case 'soy':
        assetName = 'assets/allergens/Soy Bean.png';
        break;
      case 'wheat':
        assetName = 'assets/allergens/Gluten.png';
        break;
      case 'fish':
        assetName = 'assets/allergens/Fish.png';
        break;
      case 'shellfish':
        assetName = 'assets/allergens/Crab.png';
        break;
      case 'sesame':
        assetName = 'assets/allergens/Sesame.png';
        break;
      default:
        assetName = null;
    }

    if (assetName != null) {
      return Image.asset(assetName, width: 30, height: 30);
    } else {
      return Icon(Icons.warning, color: Colors.red, size: 30);
    }
  }

  Color getAllergenColor(String allergen) {
    switch (allergen.toLowerCase()) {
      case 'milk':
        return Colors.pink.shade100;
      case 'oat':
        return Colors.blue.shade100;
      case 'egg':
        return Colors.yellow.shade100;
      case 'peanut':
        return Colors.orange.shade100;
      case 'soy':
        return Colors.green.shade100;
      case 'wheat':
        return Colors.amber.shade100;
      case 'sesame':
        return Colors.brown.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
              child: Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.red),
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
              textAlign: TextAlign.left,
            ),

            const SizedBox(height: 16),
            if (allergensFound.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contains allergen(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 16,
                runSpacing: 16,
                children:
                    allergensFound.map((allergen) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: getAllergenColor(allergen),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: getAllergenImage(allergen),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            allergen,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
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
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
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
                      'No allergens detected',
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
