import 'package:allergen/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AllergenTab extends StatefulWidget {
  final List<AllergenInfo> currentAllergens;
  final bool isUpdatingAllergens;
  final String? productName;
  final bool isOCRAnalysis;

  const AllergenTab({
    Key? key,
    required this.currentAllergens,
    required this.isUpdatingAllergens,
    this.productName,
    required this.isOCRAnalysis,
  }) : super(key: key);

  @override
  _AllergenTabState createState() => _AllergenTabState();
}

class _AllergenTabState extends State<AllergenTab> {
  List<AlternativeProduct> alternativeProducts = [];
  bool isLoadingAlternatives = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOCRAnalysis &&
        widget.currentAllergens.isNotEmpty &&
        widget.productName != null) {
      _loadAlternativeProducts();
    }
  }

  Future<void> _loadAlternativeProducts() async {
    if (widget.productName == null || widget.productName!.isEmpty) return;

    setState(() {
      isLoadingAlternatives = true;
    });

    try {
      final alternatives = await _fetchAlternativeProducts(
        widget.productName!,
        widget.currentAllergens,
      );

      setState(() {
        alternativeProducts = alternatives;
        isLoadingAlternatives = false;
      });
    } catch (e) {
      print('Error loading alternatives: $e');
      setState(() {
        isLoadingAlternatives = false;
      });
    }
  }

  Future<List<AlternativeProduct>> _fetchAlternativeProducts(
    String productName,
    List<AllergenInfo> allergens,
  ) async {
    try {
      // Extract category from product name (simple approach)
      String searchTerm = _extractCategory(productName);

      // Get allergen codes that we need to avoid
      List<String> allergenCodes = _getAllergenCodes(allergens);

      // Search Open Food Facts
      final url =
          'https://world.openfoodfacts.org/cgi/search.pl?'
          'search_terms=$searchTerm&'
          'search_simple=1&'
          'action=process&'
          'json=1&'
          'page_size=20';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final products = data['products'] as List<dynamic>? ?? [];

        List<AlternativeProduct> alternatives = [];

        for (var product in products) {
          // Skip if same product
          if (product['product_name']?.toString().toLowerCase() ==
              productName.toLowerCase())
            continue;

          // Check if product is safe (doesn't contain our allergens)
          if (_isProductSafe(product, allergenCodes)) {
            alternatives.add(
              AlternativeProduct(
                name: product['product_name'] ?? 'Unknown Product',
                brand: product['brands'] ?? '',
                imageUrl: product['image_url'] ?? '',
                allergens: _extractProductAllergens(product),
                nutritionGrade: product['nutriscore_grade'] ?? '',
              ),
            );
          }

          // Limit to 3 alternatives
          if (alternatives.length >= 3) break;
        }

        return alternatives;
      }
    } catch (e) {
      print('Error fetching alternatives: $e');
    }

    return [];
  }

  String _extractCategory(String productName) {
    String name = productName.toLowerCase();

    // Noodle and instant noodle products
    if (name.contains('pancit') ||
        name.contains('canton') ||
        name.contains('noodle') ||
        name.contains('ramen') ||
        name.contains('instant noodle') ||
        name.contains('spaghetti') ||
        name.contains('pasta') ||
        name.contains('mami') ||
        name.contains('sotanghon') ||
        name.contains('bihon') ||
        name.contains('miki')) {
      return 'noodles instant noodles';
    }

    // Dairy products
    if (name.contains('milk') ||
        name.contains('dairy') ||
        name.contains('gatas')) {
      return 'milk dairy';
    }

    // Bread and baked goods
    if (name.contains('bread') ||
        name.contains('tinapay') ||
        name.contains('pandesal') ||
        name.contains('wheat') ||
        name.contains('loaf')) {
      return 'bread baked goods';
    }

    // Cookies and biscuits
    if (name.contains('cookie') ||
        name.contains('biscuit') ||
        name.contains('galletas') ||
        name.contains('crackers')) {
      return 'cookies biscuits';
    }

    // Chocolate products
    if (name.contains('chocolate') ||
        name.contains('choco') ||
        name.contains('cocoa') ||
        name.contains('tsokolate')) {
      return 'chocolate';
    }

    // Cheese products
    if (name.contains('cheese') ||
        name.contains('keso') ||
        name.contains('queso')) {
      return 'cheese';
    }

    // Yogurt products
    if (name.contains('yogurt') ||
        name.contains('yoghurt') ||
        name.contains('greek yogurt')) {
      return 'yogurt';
    }

    // Cereal products
    if (name.contains('cereal') ||
        name.contains('cornflakes') ||
        name.contains('oats') ||
        name.contains('granola') ||
        name.contains('muesli')) {
      return 'cereal breakfast';
    }

    // Snack products
    if (name.contains('chips') ||
        name.contains('snack') ||
        name.contains('crackers') ||
        name.contains('nuts') ||
        name.contains('pretzels')) {
      return 'snacks chips';
    }

    // Rice products
    if (name.contains('rice') ||
        name.contains('bigas') ||
        name.contains('kanin') ||
        name.contains('fried rice')) {
      return 'rice';
    }

    // Canned goods
    if (name.contains('canned') ||
        name.contains('sardines') ||
        name.contains('corned beef') ||
        name.contains('lata')) {
      return 'canned goods';
    }

    // Sauce and condiments
    if (name.contains('sauce') ||
        name.contains('ketchup') ||
        name.contains('soy sauce') ||
        name.contains('vinegar') ||
        name.contains('sarsa')) {
      return 'sauce condiments';
    }

    // Beverages
    if (name.contains('juice') ||
        name.contains('drink') ||
        name.contains('soda') ||
        name.contains('water') ||
        name.contains('coffee') ||
        name.contains('tea')) {
      return 'beverages drinks';
    }

    // Meat products
    if (name.contains('meat') ||
        name.contains('beef') ||
        name.contains('pork') ||
        name.contains('chicken') ||
        name.contains('karne')) {
      return 'meat products';
    }

    // Seafood
    if (name.contains('fish') ||
        name.contains('tuna') ||
        name.contains('salmon') ||
        name.contains('shrimp') ||
        name.contains('isda')) {
      return 'seafood fish';
    }

    List<String> words = name.split(' ');
    List<String> meaningfulWords = [];

    List<String> brandNames = [
      'lucky me',
      'nestle',
      'unilever',
      'del monte',
      'maggi',
      'knorr',
    ];
    List<String> commonWords = [
      'the',
      'and',
      'or',
      'with',
      'in',
      'of',
      'me',
      'my',
    ];

    for (String word in words) {
      if (!brandNames.any((brand) => brand.contains(word)) &&
          !commonWords.contains(word) &&
          word.length > 2) {
        meaningfulWords.add(word);
      }
    }

    if (meaningfulWords.isNotEmpty) {
      return meaningfulWords.take(2).join(' ');
    }

    return name
        .replaceAll(
          RegExp(r'\b(lucky me|nestle|unilever|del monte|maggi|knorr)\b'),
          '',
        )
        .trim();
  }

  List<String> _getAllergenCodes(List<AllergenInfo> allergens) {
    Map<String, String> allergenMap = {
      'milk': 'milk',
      'dairy': 'milk',
      'eggs': 'eggs',
      'egg': 'eggs',
      'peanuts': 'peanuts',
      'peanut': 'peanuts',
      'tree nuts': 'nuts',
      'nuts': 'nuts',
      'wheat': 'gluten',
      'gluten': 'gluten',
      'soy': 'soybeans',
      'soybeans': 'soybeans',
      'fish': 'fish',
      'shellfish': 'crustaceans',
      'sesame': 'sesame-seeds',
    };

    List<String> codes = [];
    for (var allergen in allergens) {
      String code =
          allergenMap[allergen.name.toLowerCase()] ??
          allergen.name.toLowerCase();
      codes.add(code);
    }
    return codes;
  }

  bool _isProductSafe(
    Map<String, dynamic> product,
    List<String> avoidAllergens,
  ) {
    // Check allergens field
    String allergens = product['allergens'] ?? '';
    String allergensLower = allergens.toLowerCase();

    for (String allergen in avoidAllergens) {
      if (allergensLower.contains(allergen)) {
        return false;
      }
    }

    // Check ingredients for common allergen terms
    String ingredients = product['ingredients_text'] ?? '';
    String ingredientsLower = ingredients.toLowerCase();

    Map<String, List<String>> allergenTerms = {
      'milk': [
        'milk',
        'dairy',
        'cream',
        'butter',
        'cheese',
        'whey',
        'casein',
        'lactose',
      ],
      'eggs': ['egg', 'albumin', 'ovalbumin'],
      'peanuts': ['peanut', 'groundnut'],
      'nuts': ['almond', 'walnut', 'cashew', 'hazelnut', 'pecan', 'pistachio'],
      'gluten': ['wheat', 'gluten', 'barley', 'rye', 'malt'],
      'soybeans': ['soy', 'soya', 'soybean'],
    };

    for (String allergen in avoidAllergens) {
      List<String> terms = allergenTerms[allergen] ?? [allergen];
      for (String term in terms) {
        if (ingredientsLower.contains(term)) {
          return false;
        }
      }
    }

    return true;
  }

  List<String> _extractProductAllergens(Map<String, dynamic> product) {
    String allergens = product['allergens'] ?? '';
    if (allergens.isEmpty) return [];

    return allergens
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allergenic Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (widget.isUpdatingAllergens)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),

          // Allergens Display
          if (widget.currentAllergens.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  widget.currentAllergens.map((allergen) {
                    return SizedBox(
                      width: 100,
                      height: 100,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: allergen.color.withOpacity(0.1),
                          border: Border.all(
                            color: allergen.color.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              allergen.iconPath,
                              width: 32,
                              height: 32,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.warning,
                                  size: 32,
                                  color: allergen.color,
                                );
                              },
                            ),
                            SizedBox(height: 6),
                            Text(
                              allergen.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: allergen.color,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'No Allergens Detected',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'This food appears to be safe',
                    style: TextStyle(color: Colors.green[700], fontSize: 14),
                  ),
                ],
              ),
            ),

          SizedBox(height: 24),

          if (widget.isOCRAnalysis) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alternative Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isLoadingAlternatives)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            if (widget.currentAllergens.isNotEmpty)
              _buildAlternativesSection()
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'No Alternatives Needed',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'This product is safe for you!',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlternativesSection() {
    if (alternativeProducts.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              alternativeProducts.map((product) {
                return Container(
                  width: 120,
                  margin: EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              product.imageUrl.isNotEmpty
                                  ? Image.network(
                                    product.imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholderImage();
                                    },
                                  )
                                  : _buildPlaceholderImage(),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.brand.isNotEmpty)
                        Text(
                          product.brand,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (product.nutritionGrade.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getNutritionGradeColor(
                              product.nutritionGrade,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Grade ${product.nutritionGrade.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    } else {
      return Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 32, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Searching...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Safe alternatives',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood, size: 32, color: Colors.grey),
          SizedBox(height: 4),
          Text(
            'Safe Product',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNutritionGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'a':
        return Colors.green;
      case 'b':
        return Colors.lightGreen;
      case 'c':
        return Colors.orange;
      case 'd':
        return Colors.deepOrange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class AlternativeProduct {
  final String name;
  final String brand;
  final String imageUrl;
  final List<String> allergens;
  final String nutritionGrade;

  AlternativeProduct({
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.allergens,
    required this.nutritionGrade,
  });
}
