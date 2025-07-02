import 'package:allergen/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:allergen/screens/ingredientmodal.dart';

class DescriptionTab extends StatelessWidget {
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

  Color getIngredientColor(String ingredient) {
    for (var allergen in currentAllergens) {
      if (isIngredientAllergenic(ingredient, allergen)) {
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
    }
    return Colors.grey;
  }

  bool isIngredientAllergenic(String ingredient, AllergenInfo allergen) {
    String lowerIngredient = ingredient.toLowerCase();
    String lowerAllergenName = allergen.name.toLowerCase();

    if (lowerIngredient.contains(lowerAllergenName)) {
      return true;
    }

    Map<String, List<String>> technicalTerms = {
      'egg': [
        'albumin',
        'ovalbumin',
        'ovomucin',
        'ovomucoid',
        'lysozyme',
        'lecithin',
        'mayonnaise',
        'meringue',
        'custard',
        'binder',
      ],
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
      ],
      'dairy': [
        'casein',
        'whey',
        'lactose',
        'lactalbumin',
        'lactoglobulin',
        'milk',
        'cheese',
        'butter',
        'cream',
        'yogurt',
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
        'wrapper',
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
      ],
      'peanut': ['arachis', 'groundnut', 'arachis hypogaea'],
      'shellfish': [
        'crustacean',
        'mollusc',
        'chitin',
        'shrimp',
        'crab',
        'lobster',
        'crayfish',
        'oyster',
        'clam',
        'mussel',
        'scallop',
      ],
      'fish': ['anchovy', 'sardine', 'tuna', 'salmon', 'cod', 'mackerel'],
      'tree nut': [
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
      'sesame': ['tahini', 'sesamum'],
    };

    List<String> terms = technicalTerms[lowerAllergenName] ?? [];
    for (String term in terms) {
      if (lowerIngredient.contains(term)) {
        return true;
      }
    }

    if (lowerIngredient.contains('contains $lowerAllergenName') ||
        lowerIngredient.contains('with $lowerAllergenName') ||
        lowerIngredient.contains('that contains $lowerAllergenName')) {
      return true;
    }

    Map<String, List<String>> foodCombinations = {
      'egg': [
        'lumpia wrapper',
        'spring roll wrapper',
        'wonton wrapper',
        'pasta',
        'noodles',
        'bread',
        'cake',
        'cookie',
        'biscuit',
      ],
      'wheat': ['wrapper', 'dumpling skin', 'tortilla', 'pita'],
      'milk': ['chocolate', 'biscuit', 'cookie', 'cake'],
    };

    List<String> combinations = foodCombinations[lowerAllergenName] ?? [];
    for (String combo in combinations) {
      if (lowerIngredient.contains(combo)) {
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
          maxWidth:
              MediaQuery.of(context).size.width *
              0.8, // Limit width to 80% of screen
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
            horizontal: isEditing ? 10 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (!isEditing) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isSafe ? Colors.black54 : Colors.white70,
                ),
              ],
              if (isEditing) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => removeIngredient(index),
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
    return Column(
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
            description,
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
                onPressed: toggleEdit,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isEditing
                            ? Colors.red[50]
                            : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEditing ? Icons.close : Icons.edit,
                    color: isEditing ? Colors.red : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 400,
            height: 100,
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      buildColorLegendItem(Colors.grey, 'Safe'),
                      const SizedBox(width: 20),
                      buildColorLegendItem(Colors.green, 'Mild'),
                      const SizedBox(width: 20),
                      buildColorLegendItem(Colors.orange, 'Moderate'),
                      const SizedBox(width: 20),
                      buildColorLegendItem(Colors.red, 'Severe'),
                    ],
                  ),
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
                Text(
                  'Ingredients (${currentIngredients.length}):',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int i = 0; i < currentIngredients.length; i++)
                      buildIngredientChip(currentIngredients[i], i, context),
                    if (isEditing)
                      GestureDetector(
                        onTap: addIngredient,
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
          if (isEditing) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saveChanges,
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
                      onPressed: toggleEdit,
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
