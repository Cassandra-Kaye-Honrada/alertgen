import 'package:allergen/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:allergen/screens/ingredientmodal.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class DescriptionTab extends StatefulWidget {
  final String description;
  final List<String> currentIngredients;
  final List<AllergenInfo> currentAllergens;
  final bool isEditing;
  final VoidCallback toggleEdit;
  final VoidCallback addIngredient;
  final Function(int) removeIngredient;
  final VoidCallback saveChanges;

  const DescriptionTab({
    Key? key,
    required this.description,
    required this.currentIngredients,
    required this.currentAllergens,
    required this.isEditing,
    required this.toggleEdit,
    required this.addIngredient,
    required this.removeIngredient,
    required this.saveChanges,
  }) : super(key: key);

  @override
  _DescriptionTabState createState() => _DescriptionTabState();
}

class _DescriptionTabState extends State<DescriptionTab> {
  Map<String, AllergenInfo> ingredientAllergenMap = {};
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _analyzeIngredientsWithAI();
  }

  @override
  void didUpdateWidget(DescriptionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIngredients != widget.currentIngredients ||
        oldWidget.currentAllergens != widget.currentAllergens) {
      _analyzeIngredientsWithAI();
    }
  }

  Future<void> _analyzeIngredientsWithAI() async {
    if (widget.currentIngredients.isEmpty) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      const apiKey =
          'AIzaSyCzyd0ukiEilgPiJ29HNplB2UtWyOKCZkA'; // Use your API key
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-preview-04-17',
        apiKey: apiKey,
      );

      final prompt = '''
You are an expert food allergen detection AI. Analyze each ingredient and determine if it contains any of the 9 major allergens.

THE 9 MAJOR ALLERGENS:
1. Milk (dairy, casein, whey, lactose, gatas)
2. Eggs (albumin, lecithin, ovalbumin, itlog)
3. Fish (anchovies, bagoong, fish sauce, dried fish, isda)
4. Shellfish (shrimp, crab, oyster sauce, alamang, hipon)
5. Tree nuts (cashew, almonds, etc. - NOT peanuts, NOT coconut)
6. Peanuts (mani, peanut oil, groundnuts)
7. Wheat (gluten, flour, bread crumbs, harina)
8. Soy (soy sauce, tofu, soybean oil, toyo)
9. Sesame (sesame oil, tahini, linga)

TECHNICAL INGREDIENT MAPPING:
- Albumin, Ovalbumin, Ovomucin → Eggs
- Casein, Whey, Lactose, Lactalbumin → Milk
- Lecithin → Usually Soy (can be from eggs)
- Monosodium glutamate (MSG) → Usually safe (from fermentation)
- Sodium benzoate, Potassium sorbate → Preservatives (safe)
- Ascorbic acid → Vitamin C (safe)
- Tocopherols → Vitamin E (safe)
- BHT/BHA → Antioxidants (safe)
- Carrageenan → Seaweed extract (safe)
- Gluten, Gliadin, Glutenin → Wheat
- Arachis hypogaea → Peanuts
- Glycine max → Soy
- Triticum → Wheat

FILIPINO INGREDIENTS:
- Bagoong, Patis (fish sauce) → Fish
- Alamang, Hipon → Shellfish
- Toyo → Soy
- Gatas → Milk
- Itlog → Eggs
- Mani → Peanuts
- Harina → Wheat
- Coconut milk/Gata → SAFE (not tree nuts)

SEVERITY LEVELS:
- severe: Direct allergen source (e.g., milk powder, egg whites, peanuts)
- moderate: Processed forms or derivatives (e.g., casein, whey, lecithin)
- mild: Trace amounts or cross-contamination risk
- safe: No allergens detected

CURRENT DETECTED ALLERGENS: ${widget.currentAllergens.map((a) => '${a.name} (${a.riskLevel})').join(', ')}

INGREDIENTS TO ANALYZE: ${widget.currentIngredients.join(', ')}

For each ingredient, determine:
1. If it contains any allergen
2. Which specific allergen(s)
3. The severity level
4. The source/reason for the allergen

Return JSON in this format:
{
  "ingredientAnalysis": {
    "ingredient_name": {
      "hasAllergen": true/false,
      "allergen": "allergen_name or null",
      "severity": "severe|moderate|mild|safe",
      "source": "explanation of why this ingredient contains the allergen"
    }
  }
}

IMPORTANT:
- Only detect allergens that are actually present
- Be conservative and accurate
- Match the detected allergens with the current allergen list
- Consider both direct sources and technical/chemical names
- For Filipino ingredients, use proper allergen mapping
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String cleanResponse = response.text ?? '';

      if (cleanResponse.contains('```json')) {
        cleanResponse = cleanResponse.split('```json')[1].split('```')[0];
      } else if (cleanResponse.contains('```')) {
        cleanResponse = cleanResponse.split('```')[1];
      }

      final jsonData = json.decode(cleanResponse.trim());
      final analysis = jsonData['ingredientAnalysis'] as Map<String, dynamic>;

      Map<String, AllergenInfo> newMap = {};

      for (String ingredient in widget.currentIngredients) {
        // Find matching analysis (case-insensitive)
        String? matchingKey;
        for (String key in analysis.keys) {
          if (key.toLowerCase() == ingredient.toLowerCase() ||
              ingredient.toLowerCase().contains(key.toLowerCase()) ||
              key.toLowerCase().contains(ingredient.toLowerCase())) {
            matchingKey = key;
            break;
          }
        }

        if (matchingKey != null) {
          final ingredientData = analysis[matchingKey];
          if (ingredientData['hasAllergen'] == true) {
            String allergenName = ingredientData['allergen'];

            // Find matching allergen from current allergens
            AllergenInfo? matchingAllergen = widget.currentAllergens.firstWhere(
              (a) => a.name.toLowerCase() == allergenName.toLowerCase(),
              orElse:
                  () => AllergenInfo(
                    name: allergenName,
                    riskLevel: ingredientData['severity'] ?? 'safe',
                    symptoms: [],
                    source: ingredientData['source'] ?? ingredient,
                  ),
            );

            newMap[ingredient] = matchingAllergen;
          }
        }
      }

      setState(() {
        ingredientAllergenMap = newMap;
        isAnalyzing = false;
      });
    } catch (e) {
      print('Error analyzing ingredients with AI: $e');
      setState(() {
        isAnalyzing = false;
      });
      // Fallback to basic mapping
      _fallbackAllergenMapping();
    }
  }

  void _fallbackAllergenMapping() {
    Map<String, AllergenInfo> newMap = {};

    for (String ingredient in widget.currentIngredients) {
      for (AllergenInfo allergen in widget.currentAllergens) {
        if (_isIngredientAllergenic(ingredient, allergen)) {
          newMap[ingredient] = allergen;
          break;
        }
      }
    }

    setState(() {
      ingredientAllergenMap = newMap;
    });
  }

  Color getIngredientColor(String ingredient) {
    if (ingredientAllergenMap.containsKey(ingredient)) {
      AllergenInfo allergen = ingredientAllergenMap[ingredient]!;
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
    return Colors.grey;
  }

  bool _isIngredientAllergenic(String ingredient, AllergenInfo allergen) {
    String lowerIngredient = ingredient.toLowerCase();
    String lowerAllergenName = allergen.name.toLowerCase();

    // Check allergen source
    if (allergen.source.isNotEmpty &&
        lowerIngredient.contains(allergen.source.toLowerCase())) {
      return true;
    }

    // Enhanced technical terms mapping
    Map<String, List<String>> allergenMapping = {
      'milk': [
        'casein',
        'whey',
        'lactose',
        'lactalbumin',
        'lactoglobulin',
        'cheese',
        'butter',
        'cream',
        'yogurt',
        'dairy',
        'gatas',
        'milk powder',
        'skim milk',
        'whole milk',
        'buttermilk',
      ],
      'eggs': [
        'albumin',
        'ovalbumin',
        'ovomucin',
        'ovomucoid',
        'lysozyme',
        'lecithin',
        'mayonnaise',
        'meringue',
        'custard',
        'itlog',
        'egg white',
        'egg yolk',
        'whole egg',
        'egg powder',
      ],
      'wheat': [
        'gluten',
        'gliadin',
        'glutenin',
        'wheat protein',
        'triticum',
        'flour',
        'bread',
        'pasta',
        'noodle',
        'harina',
        'wheat starch',
        'wheat germ',
        'wheat bran',
        'semolina',
        'durum',
      ],
      'soy': [
        'lecithin',
        'tofu',
        'tempeh',
        'miso',
        'glycine max',
        'soybean',
        'soya',
        'edamame',
        'toyo',
        'soy sauce',
        'soy protein',
        'soy flour',
        'soy oil',
        'hydrolyzed soy protein',
      ],
      'fish': [
        'anchovy',
        'sardine',
        'tuna',
        'salmon',
        'cod',
        'mackerel',
        'bagoong',
        'patis',
        'fish sauce',
        'dried fish',
        'isda',
        'fish oil',
        'fish protein',
        'fish extract',
      ],
      'shellfish': [
        'shrimp',
        'crab',
        'lobster',
        'crayfish',
        'oyster',
        'clam',
        'mussel',
        'scallop',
        'alamang',
        'hipon',
        'crustacean',
        'mollusk',
        'oyster sauce',
        'shrimp paste',
      ],
      'peanuts': [
        'peanut',
        'groundnut',
        'arachis hypogaea',
        'mani',
        'peanut oil',
        'peanut butter',
        'peanut flour',
        'peanut protein',
      ],
      'tree nuts': [
        'almond',
        'cashew',
        'walnut',
        'pecan',
        'pistachio',
        'hazelnut',
        'macadamia',
        'brazil nut',
        'pine nut',
        'nut oil',
        'nut butter',
        'nut flour',
      ],
      'sesame': [
        'sesame',
        'tahini',
        'sesamum',
        'linga',
        'sesame oil',
        'sesame seed',
        'sesame paste',
      ],
    };

    // Check if ingredient contains any allergen-related terms
    List<String> terms = allergenMapping[lowerAllergenName] ?? [];
    for (String term in terms) {
      if (lowerIngredient.contains(term)) {
        return true;
      }
    }

    return false;
  }

  Widget buildIngredientChip(
    String ingredient,
    int index,
    BuildContext context,
  ) {
    Color chipColor = getIngredientColor(ingredient);
    bool isSafe = chipColor == Colors.grey;
    bool hasAllergen = ingredientAllergenMap.containsKey(ingredient);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
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
            horizontal: widget.isEditing ? 10 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAllergen) ...[
                Icon(
                  Icons.warning,
                  size: 12,
                  color: isSafe ? Colors.black54 : Colors.white,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  ingredient,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSafe ? Colors.black87 : Colors.white,
                    fontWeight: isSafe ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              if (!widget.isEditing) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isSafe ? Colors.black54 : Colors.white70,
                ),
              ],
              if (widget.isEditing) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => widget.removeIngredient(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
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

  Widget buildColorLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scanned Ingredients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: widget.toggleEdit,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        widget.isEditing
                            ? Colors.red[50]
                            : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isEditing ? Icons.close : Icons.edit,
                    color: widget.isEditing ? Colors.red : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color Legend:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    buildColorLegendItem(Colors.grey, 'Safe'),
                    buildColorLegendItem(Colors.green, 'Mild'),
                    buildColorLegendItem(Colors.orange, 'Moderate'),
                    buildColorLegendItem(Colors.red, 'Severe'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(16),
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
                Row(
                  children: [
                    Text(
                      'Ingredients (${widget.currentIngredients.length}):',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textBlack,
                      ),
                    ),
                    if (isAnalyzing) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int i = 0; i < widget.currentIngredients.length; i++)
                      buildIngredientChip(
                        widget.currentIngredients[i],
                        i,
                        context,
                      ),
                    if (widget.isEditing)
                      GestureDetector(
                        onTap: widget.addIngredient,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
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
          if (widget.isEditing) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.toggleEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
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
}
