import 'dart:convert';
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

      simplifiedIngredient = await getSimplifiedIngredient(widget.ingredient);

      final usdaAllergens = await getAllergenInfoFromUSDA(simplifiedIngredient);

      setState(() {
        allergensFound = usdaAllergens['allergens'] ?? [];
        riskLevel = usdaAllergens['risk'] ?? 'Unknown';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
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

  IconData _getAllergenIcon(String allergen) {
    switch (allergen.toLowerCase()) {
      case 'milk':
        return Icons.local_drink;
      case 'egg':
        return Icons.egg;
      case 'peanut':
        return Icons.scatter_plot;
      case 'soy':
        return Icons.eco;
      case 'wheat':
        return Icons.grass;
      case 'tree nut':
        return Icons.park;
      case 'shellfish':
        return Icons.set_meal;
      case 'fish':
        return Icons.set_meal;
      case 'oat':
        return Icons.grain;
      case 'sesame':
        return Icons.circle;
      default:
        return Icons.warning;
    }
  }

  Color _getAllergenColor(String allergen) {
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
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with back button
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
                  color: Colors.blue,
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
            // Ingredient name
            Text(
              simplifiedIngredient.isNotEmpty
                  ? simplifiedIngredient
                  : widget.ingredient,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

            // Allergen warning
            if (allergensFound.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contains an allergen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Allergen icons
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
                              color: _getAllergenColor(allergen),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getAllergenIcon(allergen),
                              size: 30,
                              color: Colors.red.shade400,
                            ),
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
