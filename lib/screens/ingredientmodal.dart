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
  String allergensFound = '';
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
        allergensFound = usdaAllergens['allergens'] ?? 'None';
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

  Future<Map<String, String>> getAllergenInfoFromUSDA(String ingredient) async {
    final url =
        'https://api.nal.usda.gov/fdc/v1/foods/search?query=$ingredient&api_key=$usdaApiKey&pageSize=1';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch data from USDA');
    }

    final data = json.decode(response.body);
    final foods = data['foods'] as List<dynamic>;

    if (foods.isEmpty) {
      return {'allergens': 'None', 'risk': 'Safe'};
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
    ];

    for (var allergen in knownAllergens) {
      if (description.contains(allergen)) {
        return {
          'allergens': allergen[0].toUpperCase() + allergen.substring(1),
          'risk': 'Likely Risk',
        };
      }
    }

    return {'allergens': 'None', 'risk': 'Safe'};
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Text('Error: $errorMessage')
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Ingredient: ${widget.ingredient}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text('Simplified: $simplifiedIngredient'),
                  const SizedBox(height: 10),
                  Text('Allergens: $allergensFound'),
                  const SizedBox(height: 10),
                  Text('Risk Level: $riskLevel'),
                  const SizedBox(height: 20),
                ],
              ),
    );
  }
}
