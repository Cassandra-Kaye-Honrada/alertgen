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
  String detectionMethod = '';

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

      // Step 1: First simplify the ingredient using AI
      final simplifiedResult = await simplifyIngredientWithAI(
        widget.ingredient,
      );
      String ingredientToAnalyze =
          simplifiedResult['simplified'] ?? widget.ingredient;

      setState(() {
        simplifiedIngredient = ingredientToAnalyze;
      });

      // Step 2: Try USDA API with the simplified ingredient
      final usdaResult = await checkUSDADatabaseEnhanced(ingredientToAnalyze);

      if (usdaResult['found'] == true) {
        final allergenAnalysis = await analyzeUSDADataForAllergens(
          usdaResult['data'],
        );

        if (allergenAnalysis['allergens'].isNotEmpty) {
          setState(() {
            allergensFound = allergenAnalysis['allergens'];
            riskLevel = allergenAnalysis['risk'];
            detectionMethod = 'USDA Database';
            isLoading = false;
          });
          return;
        }
      }

      // Step 3: Fallback to AI analysis if USDA doesn't find allergens
      final aiResult = await getEnhancedAIAllergenAnalysis(ingredientToAnalyze);

      setState(() {
        allergensFound = aiResult['allergens'] ?? [];
        riskLevel = aiResult['risk'] ?? 'Safe';
        detectionMethod =
            aiResult['allergens']?.isNotEmpty == true
                ? 'AI Analysis'
                : 'No allergens detected';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
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
Simplify this ingredient name to its core components for food database search.

INGREDIENT: "$ingredient"

RULES:
1. Remove brand names, cooking methods, and descriptive words
2. Keep only the essential food item name
3. If it's a sauce or complex dish, identify the main ingredients
4. Convert to simple, searchable terms
5. For Filipino/local terms, provide English equivalents

EXAMPLES:
- "Fried chicken with garlic sauce" → "chicken"
- "Sweet and sour pork" → "pork, sweet and sour sauce"
- "Coca-Cola" → "cola"
- "Knorr chicken cube" → "chicken bouillon"
- "Patis" → "fish sauce"

Return JSON:
{
  "simplified": "simplified_ingredient_name",
  "components": ["component1", "component2"]
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String cleanResponse = response.text ?? '';

      if (cleanResponse.contains('```json')) {
        cleanResponse = cleanResponse.split('```json')[1].split('```')[0];
      }

      final jsonData = json.decode(cleanResponse.trim());

      return {
        'simplified': jsonData['simplified'] ?? ingredient,
        'components':
            (jsonData['components'] as List?)?.cast<String>() ?? [ingredient],
      };
    } catch (e) {
      return {
        'simplified': ingredient,
        'components': [ingredient],
      };
    }
  }

  // Enhanced rule-based detection with comprehensive patterns
  Map<String, dynamic> detectAllergensWithEnhancedRules(String ingredient) {
    List<String> allergens = [];
    String lowerIngredient = ingredient.toLowerCase();

    // Comprehensive allergen detection patterns
    final Map<String, List<String>> allergenPatterns = {
      'milk': [
        'milk',
        'dairy',
        'cheese',
        'butter',
        'cream',
        'whey',
        'casein',
        'lactose',
        'yogurt',
        'kefir',
        'buttermilk',
        'ghee',
        'condensed milk',
        'evaporated milk',
        'skim milk',
        'whole milk',
        'milk powder',
        'sodium caseinate',
        'calcium caseinate',
        'lactalbumin',
        'lactoglobulin',
        'gatas',
        'kesong puti',
      ],
      'eggs': [
        'egg',
        'albumin',
        'lecithin',
        'ovalbumin',
        'ovomucin',
        'ovotransferrin',
        'egg white',
        'egg yolk',
        'egg powder',
        'dried egg',
        'mayonnaise',
        'meringue',
        'custard',
        'eggnog',
        'itlog',
        'balut',
      ],
      'wheat': [
        'wheat',
        'flour',
        'gluten',
        'bread',
        'pasta',
        'noodles',
        'semolina',
        'bulgur',
        'couscous',
        'spelt',
        'kamut',
        'farro',
        'durum',
        'graham',
        'vital wheat gluten',
        'wheat starch',
        'wheat bran',
        'wheat germ',
        'bread crumbs',
        'panko',
        'harina',
        'tinapay',
      ],
      'soy': [
        'soy',
        'soya',
        'tofu',
        'tempeh',
        'miso',
        'soy sauce',
        'shoyu',
        'tamari',
        'soybean oil',
        'soy protein',
        'soy flour',
        'soy lecithin',
        'edamame',
        'natto',
        'soy milk',
        'textured soy protein',
        'tvp',
        'hydrolyzed soy protein',
        'toyo',
        'tokwa',
      ],
      'peanuts': [
        'peanut',
        'groundnut',
        'arachis',
        'peanut oil',
        'peanut butter',
        'peanut flour',
        'peanut protein',
        'monkey nut',
        'goober',
        'mani',
        'peanut paste',
      ],
      'fish': [
        'fish',
        'salmon',
        'tuna',
        'cod',
        'mackerel',
        'sardine',
        'anchovy',
        'trout',
        'bass',
        'tilapia',
        'bangus',
        'galunggong',
        'fish sauce',
        'patis',
        'bagoong',
        'fish oil',
        'fish stock',
        'dried fish',
        'fish powder',
        'worcestershire sauce',
        'caesar dressing',
        'isda',
      ],
      'shellfish': [
        'shrimp',
        'crab',
        'lobster',
        'oyster',
        'clam',
        'mussel',
        'scallop',
        'abalone',
        'squid',
        'octopus',
        'cuttlefish',
        'prawn',
        'crayfish',
        'langostino',
        'oyster sauce',
        'shrimp paste',
        'bagoong alamang',
        'hipon',
        'alimango',
        'tahong',
        'pusit',
      ],
      'tree nuts': [
        'almond',
        'walnut',
        'cashew',
        'pistachio',
        'pecan',
        'hazelnut',
        'brazil nut',
        'macadamia',
        'pine nut',
        'chestnut',
        'filbert',
        'hickory nut',
        'butternut',
        'chinquapin',
        'ginkgo nut',
        'lychee nut',
        'shea nut',
        'kasuy',
        'pili nut',
      ],
      'sesame': [
        'sesame',
        'tahini',
        'sesame oil',
        'sesame seed',
        'sesame paste',
        'gomasio',
        'halvah',
        'benne',
        'sim sim',
        'til',
        'linga',
      ],
    };

    // Check for each allergen pattern
    for (String allergen in allergenPatterns.keys) {
      for (String pattern in allergenPatterns[allergen]!) {
        if (lowerIngredient.contains(pattern)) {
          if (!allergens.contains(allergen)) {
            allergens.add(allergen);
          }
          break; // Found this allergen, move to next
        }
      }
    }

    // Special case handling for common compound ingredients
    if (lowerIngredient.contains('sweet and sour sauce') ||
        lowerIngredient.contains('sweet & sour sauce')) {
      if (!allergens.contains('soy')) {
        allergens.add(
          'soy',
        ); // Most commercial sweet and sour sauces contain soy
      }
    }

    if (lowerIngredient.contains('teriyaki sauce')) {
      if (!allergens.contains('soy')) {
        allergens.add('soy');
      }
      if (!allergens.contains('wheat')) {
        allergens.add('wheat');
      }
    }

    if (lowerIngredient.contains('hoisin sauce')) {
      if (!allergens.contains('soy')) {
        allergens.add('soy');
      }
    }

    return {
      'allergens': allergens,
      'risk': allergens.isNotEmpty ? 'Contains allergen' : 'Safe',
    };
  }

  Future<Map<String, dynamic>> checkUSDADatabaseEnhanced(
    String ingredient,
  ) async {
    try {
      // Get simplified components first
      final simplifiedResult = await simplifyIngredientWithAI(ingredient);
      List<String> componentsToSearch =
          simplifiedResult['components'] ?? [ingredient];

      // Add the original ingredient and its variations
      List<String> searchTerms = [
        ingredient,
        simplifiedResult['simplified'] ?? ingredient,
        ...componentsToSearch,
      ];

      // Add word variations
      for (String term in List.from(searchTerms)) {
        if (term.contains(' ')) {
          searchTerms.add(term.split(' ').first); // First word
          searchTerms.add(term.split(' ').last); // Last word
        }

        // Remove common words
        if (term.toLowerCase().contains('sauce')) {
          searchTerms.add(term.toLowerCase().replaceAll('sauce', '').trim());
        }
      }

      // Remove duplicates and short terms
      searchTerms =
          searchTerms.toSet().where((term) => term.length >= 3).toList();

      for (String searchTerm in searchTerms) {
        final url =
            'https://api.nal.usda.gov/fdc/v1/foods/search?query=${Uri.encodeComponent(searchTerm)}&api_key=$usdaApiKey&pageSize=10';

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final foods = data['foods'] as List<dynamic>;

          if (foods.isNotEmpty) {
            List<String> foodDescriptions = [];
            for (var food in foods.take(5)) {
              final description = food['description'].toString();
              final brandOwner = food['brandOwner']?.toString() ?? '';
              final ingredients = food['ingredients']?.toString() ?? '';

              String foodInfo = description;
              if (brandOwner.isNotEmpty) foodInfo += ' by $brandOwner';
              if (ingredients.isNotEmpty)
                foodInfo += ' ingredients: $ingredients';

              foodDescriptions.add(foodInfo);
            }

            return {
              'found': true,
              'data': foodDescriptions.join('\n'),
              'searchTerm': searchTerm,
            };
          }
        }
      }

      return {'found': false, 'data': null};
    } catch (e) {
      return {'found': false, 'data': null};
    }
  }

  // Remove the old detectAllergensWithEnhancedRules method from analyzeIngredient
  // Keep it as a helper method for USDA data analysis only
  Future<Map<String, dynamic>> analyzeUSDADataForAllergens(
    String usdaFoodData,
  ) async {
    // First try rule-based detection on USDA data
    final ruleBasedResult = detectAllergensWithEnhancedRules(usdaFoodData);
    if (ruleBasedResult['allergens'].isNotEmpty) {
      return ruleBasedResult;
    }

    // If rule-based detection finds nothing, use AI
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final prompt = '''
Analyze this USDA food database information and identify ALL allergens present.

THE 9 MAJOR ALLERGENS (be thorough):
1. Milk/Dairy: milk, cheese, butter, cream, whey, casein, lactose, yogurt, etc.
2. Eggs: egg, albumin, lecithin, ovalbumin, mayonnaise, etc.
3. Fish: any fish species, fish sauce, anchovy, worcestershire sauce, etc.
4. Shellfish: shrimp, crab, lobster, oyster sauce, etc.
5. Tree nuts: almonds, walnuts, cashews, etc. (NOT peanuts, NOT coconut)
6. Peanuts: peanut, groundnut, arachis, peanut oil, etc.
7. Wheat: wheat, flour, gluten, bread, pasta, etc.
8. Soy: soy, soya, tofu, soy sauce, miso, etc.
9. Sesame: sesame, tahini, sesame oil, etc.

USDA FOOD DATA:
$usdaFoodData

IMPORTANT NOTES:
- Sweet and sour sauce typically contains SOY (soy sauce)
- Teriyaki sauce contains SOY and WHEAT
- Fish sauce contains FISH
- Oyster sauce contains SHELLFISH
- Look for hidden allergens in ingredient lists

Return JSON:
{
  "allergens": ["allergen1", "allergen2"],
  "risk": "Contains allergen"
}

Be thorough and don't miss common allergens!
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String cleanResponse = response.text ?? '';

      if (cleanResponse.contains('```json')) {
        cleanResponse = cleanResponse.split('```json')[1].split('```')[0];
      }

      final jsonData = json.decode(cleanResponse.trim());

      return {
        'allergens':
            (jsonData['allergens'] as List?)?.cast<String>() ?? <String>[],
        'risk':
            (jsonData['allergens'] as List?)?.isNotEmpty == true
                ? 'Contains allergen'
                : 'Safe',
      };
    } catch (e) {
      return ruleBasedResult;
    }
  }

  Future<Map<String, dynamic>> getEnhancedAIAllergenAnalysis(
    String ingredient,
  ) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final prompt = '''
You are an expert food allergen detection system. Analyze this ingredient thoroughly.

INGREDIENT: "$ingredient"

THE 9 MAJOR ALLERGENS TO DETECT:
1. Milk/Dairy: milk, cheese, butter, cream, whey, casein, lactose, etc.
2. Eggs: egg, albumin, lecithin, ovalbumin, mayonnaise, etc.
3. Fish: any fish, fish sauce, anchovy, worcestershire sauce, etc.
4. Shellfish: shrimp, crab, lobster, oyster sauce, etc.
5. Tree nuts: almonds, walnuts, cashews, etc. (NOT peanuts, NOT coconut)
6. Peanuts: peanut, groundnut, arachis, etc.
7. Wheat: wheat, flour, gluten, bread, pasta, etc.
8. Soy: soy, soya, tofu, soy sauce, miso, etc.
9. Sesame: sesame, tahini, sesame oil, etc.

CRITICAL DETECTION RULES:
- "Sweet and sour sauce" = contains SOY (soy sauce is main ingredient)
- "Fish" ingredients = contains FISH only (not shellfish unless specifically mentioned)
- "Fried fish" = contains FISH only
- Look for compound ingredients that hide allergens
- Consider Filipino/Asian food terms: patis (fish sauce), toyo (soy sauce), etc.

Return JSON format:
{
  "allergens": ["specific_allergen_names"],
  "risk": "Contains allergen" or "Safe"
}

IMPORTANT: Be accurate and don't add allergens that aren't actually present!
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String cleanResponse = response.text ?? '';

      if (cleanResponse.contains('```json')) {
        cleanResponse = cleanResponse.split('```json')[1].split('```')[0];
      }

      final jsonData = json.decode(cleanResponse.trim());

      return {
        'allergens':
            (jsonData['allergens'] as List?)?.cast<String>() ?? <String>[],
        'risk':
            (jsonData['allergens'] as List?)?.isNotEmpty == true
                ? 'Contains allergen'
                : 'Safe',
      };
    } catch (e) {
      return {'allergens': <String>[], 'risk': 'Safe'};
    }
  }

  Widget getAllergenImage(String allergen) {
    String? assetName;
    switch (allergen.toLowerCase()) {
      case 'milk':
        assetName = 'assets/allergens/Milk.png';
        break;
      case 'egg':
      case 'eggs':
        assetName = 'assets/allergens/Eggs.png';
        break;
      case 'peanut':
      case 'peanuts':
        assetName = 'assets/allergens/Nuts.png';
        break;
      case 'tree nut':
      case 'tree nuts':
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
        return const Color.fromARGB(255, 213, 230, 235);
      case 'egg':
      case 'eggs':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'peanut':
      case 'peanuts':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'tree nut':
      case 'tree nuts':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'soy':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'wheat':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'fish':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'shellfish':
        return const Color.fromARGB(255, 213, 230, 235);
      case 'sesame':
        return const Color.fromARGB(255, 213, 230, 235);
      default:
        return const Color.fromARGB(255, 213, 230, 235);
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
                    'Error: $errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: analyzeIngredient,
                    child: const Text('Retry'),
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
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 12),

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
                            child: Center(child: getAllergenImage(allergen)),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 60,
                            child: Text(
                              allergen,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
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
