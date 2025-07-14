import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:allergen/screens/scan_screen.dart'; // For AllergenInfo
import 'package:allergen/styleguide.dart';

class IngredientAllergenModal extends StatefulWidget {
  final String ingredient;
  final List<AllergenInfo> currentAllergens;

  const IngredientAllergenModal({
    Key? key,
    required this.ingredient,
    required this.currentAllergens,
  }) : super(key: key);

  @override
  State<IngredientAllergenModal> createState() =>
      IngredientAllergenModalState();
}

class IngredientAllergenModalState extends State<IngredientAllergenModal> {
  bool isLoading = true;
  String simplifiedIngredient = '';
  List<AllergenInfo> allergensFound = [];
  String detectionMethod = '';
  String? errorMessage;

  final String usdaApiKey = 'CKNlV96OlhW76cXyo151cbnEKe0e6P2Up85QVlTs';
  final String geminiApiKey = 'AIzaSyCzyd0ukiEilgPiJ29HNplB2UtWyOKCZkA';

  @override
  void initState() {
    super.initState();
    analyzeIngredient();
  }

  Future<void> analyzeIngredient() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Simplify ingredient using AI
      final simplifiedResult = await simplifyIngredientWithAI(
        widget.ingredient,
      );
      final ingredientToAnalyze =
          simplifiedResult['simplified'] ?? widget.ingredient;

      setState(() {
        simplifiedIngredient = ingredientToAnalyze;
      });

      // Check for allergens using AI
      final aiAllergens = await getAIAllergenAnalysis(ingredientToAnalyze);

      // Verify with USDA API
      final usdaResult = await checkUSDADatabase(ingredientToAnalyze);
      final usdaAllergens =
          usdaResult['found'] == true
              ? await analyzeUSDADataForAllergens(usdaResult['data'])
              : <AllergenInfo>[];

      // Combine results with proper deduplication
      final Map<String, AllergenInfo> allergenMap = {};

      // Add AI allergens first
      for (final allergen in aiAllergens) {
        final key = allergen.name.toLowerCase().trim();
        if (!allergenMap.containsKey(key)) {
          allergenMap[key] = allergen;
        }
      }

      // Add USDA allergens, but don't override AI ones
      for (final allergen in usdaAllergens) {
        final key = allergen.name.toLowerCase().trim();
        if (!allergenMap.containsKey(key)) {
          allergenMap[key] = allergen;
        }
      }

      // Filter to only include allergens that are in the user's current allergens list
      final List<AllergenInfo> filteredAllergens =
          allergenMap.values
              .where(
                (allergen) => widget.currentAllergens.any(
                  (currentAllergen) =>
                      _normalizeAllergenName(currentAllergen.name) ==
                      _normalizeAllergenName(allergen.name),
                ),
              )
              .toList();

      setState(() {
        allergensFound = filteredAllergens;
        detectionMethod =
            usdaResult['found'] == true
                ? 'USDA Database with AI Verification'
                : 'AI Analysis';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error analyzing ingredient: $e';
        isLoading = false;
      });
    }
  }

  // Helper method to normalize allergen names for comparison
  String _normalizeAllergenName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll('eggs', 'egg')
        .replaceAll('peanuts', 'peanut')
        .replaceAll('tree nuts', 'tree nut');
  }

  Future<List<AllergenInfo>> getAIAllergenAnalysis(String ingredient) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );
      final prompt = '''
Analyze this specific ingredient for allergens. Be VERY STRICT and only detect allergens that are ACTUALLY present in the ingredient.

INGREDIENT: "$ingredient"

CURRENT ALLERGENS TO CHECK FOR:
${widget.currentAllergens.map((a) => '- ${a.name} (${a.source})').join('\n')}

STRICT RULES:
- Only detect allergens that are DEFINITELY present in this specific ingredient
- Do NOT assume allergens unless they are clearly present
- For soy sauce: contains SOY and WHEAT (not eggs unless specifically stated)
- For patis (fish sauce): contains FISH only
- For oyster sauce: contains SHELLFISH only
- Be conservative - if unsure, don't include the allergen
- Consider common/technical names (e.g., casein=milk, lecithin=soy)

EXAMPLES:
- "soy sauce" → soy, wheat
- "fish sauce" → fish
- "oyster sauce" → shellfish
- "chicken" → none (unless prepared with allergens)

Return JSON with ONLY the allergens that are actually present:
{
  "allergens": [
    {"name": "allergen_name", "riskLevel": "severe|moderate|mild", "source": "brief_explanation"}
  ]
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final cleanResponse = _extractJson(response.text ?? '');
      final jsonData = json.decode(cleanResponse);
      final allergenList = jsonData['allergens'] as List<dynamic>? ?? [];

      return allergenList
          .map(
            (item) => AllergenInfo(
              name: item['name'] ?? '',
              riskLevel: item['riskLevel'] ?? 'moderate',
              source: item['source'] ?? '',
              symptoms: [],
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> simplifyIngredientWithAI(
    String ingredient,
  ) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );
      final prompt = '''
Simplify this ingredient for allergen analysis. Focus on the main food item.

INGREDIENT: "$ingredient"

RULES:
- Remove brand names, cooking methods, descriptive words
- Keep the core ingredient name
- For sauces/dishes, keep the sauce/dish name (don't break it down)
- Filipino terms to English: patis=fish sauce, toyo=soy sauce

EXAMPLES:
- "Fried chicken with garlic sauce" → "chicken"
- "Patis" → "fish sauce"
- "Kikkoman Soy Sauce" → "soy sauce"

Return JSON:
{
  "simplified": "simplified_ingredient_name"
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final cleanResponse = _extractJson(response.text ?? '');
      final jsonData = json.decode(cleanResponse);

      return {'simplified': jsonData['simplified'] ?? ingredient};
    } catch (e) {
      return {'simplified': ingredient};
    }
  }

  Future<Map<String, dynamic>> checkUSDADatabase(String ingredient) async {
    try {
      final url =
          'https://api.nal.usda.gov/fdc/v1/foods/search?query=${Uri.encodeComponent(ingredient)}&api_key=$usdaApiKey&pageSize=3';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final foods = data['foods'] as List<dynamic>? ?? [];

        if (foods.isNotEmpty) {
          final foodDescriptions = foods
              .take(3)
              .map((food) {
                final description = food['description']?.toString() ?? '';
                final ingredients = food['ingredients']?.toString() ?? '';
                return ingredients.isNotEmpty
                    ? '$description (Ingredients: $ingredients)'
                    : description;
              })
              .join('\n');

          return {'found': true, 'data': foodDescriptions};
        }
      }
      return {'found': false, 'data': null};
    } catch (e) {
      return {'found': false, 'data': null};
    }
  }

  Future<List<AllergenInfo>> analyzeUSDADataForAllergens(
    String usdaFoodData,
  ) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );
      final prompt = '''
Analyze this USDA data for allergens. Be STRICT and only detect allergens that are clearly present.

CURRENT ALLERGENS TO CHECK FOR:
${widget.currentAllergens.map((a) => '- ${a.name}: ${a.source}').join('\n')}

USDA DATA:
$usdaFoodData

STRICT RULES:
- Only detect allergens that are clearly mentioned in the data
- Be conservative - if unsure, don't include the allergen
- Look for actual ingredient names, not assumptions

Return JSON:
{
  "allergens": [
    {"name": "allergen_name", "riskLevel": "severe|moderate|mild", "source": "explanation"}
  ]
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final cleanResponse = _extractJson(response.text ?? '');
      final jsonData = json.decode(cleanResponse);

      final allergenList =
          (jsonData['allergens'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      return allergenList
          .map(
            (item) => AllergenInfo(
              name: item['name'] ?? '',
              riskLevel: item['riskLevel'] ?? 'moderate',
              source: item['source'] ?? '',
              symptoms: [],
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  String _extractJson(String response) {
    final jsonMatch = RegExp(r'```json\n([\s\S]*?)\n```').firstMatch(response);
    return jsonMatch?.group(1)?.trim() ?? response.trim();
  }

  Widget getAllergenImage(String allergen) {
    const allergenImages = {
      'milk': 'assets/allergens/Milk.png',
      'egg': 'assets/allergens/Eggs.png',
      'eggs': 'assets/allergens/Eggs.png',
      'peanut': 'assets/allergens/Nuts.png',
      'peanuts': 'assets/allergens/Nuts.png',
      'tree nut': 'assets/allergens/Cashew.png',
      'tree nuts': 'assets/allergens/Cashew.png',
      'soy': 'assets/allergens/Soy Bean.png',
      'wheat': 'assets/allergens/Gluten.png',
      'fish': 'assets/allergens/Fish.png',
      'shellfish': 'assets/allergens/Crab.png',
      'sesame': 'assets/allergens/Sesame.png',
    };
    final assetName = allergenImages[allergen.toLowerCase()];
    return assetName != null
        ? Image.asset(assetName, width: 30, height: 30)
        : Icon(Icons.warning, color: Colors.red, size: 30);
  }

  Color getAllergenColor(AllergenInfo allergen) {
    return {
          'severe': Colors.red,
          'moderate': Colors.orange,
          'mild': Colors.green,
          'safe': Colors.grey,
        }[allergen.riskLevel.toLowerCase()] ??
        Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              ),
              const Text(
                'About the ingredient',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (errorMessage != null)
            Column(
              children: [
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: analyzeIngredient,
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ingredient,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                allergensFound.isEmpty
                    ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'No allergens detected',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
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
                                'Contains ${allergensFound.length} allergen${allergensFound.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children:
                              allergensFound
                                  .map(
                                    (allergen) => SizedBox(
                                      width: 60,
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: getAllergenImage(
                                                allergen.name,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            allergen.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
}
