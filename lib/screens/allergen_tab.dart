import 'package:allergen/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  AllergenTabState createState() => AllergenTabState();
}

class AllergenTabState extends State<AllergenTab> {
  List<AlternativeProduct> alternativeProducts = [];
  bool isLoadingAlternatives = false;
  Set<String> userAllergens = {}; // Store user's allergens
  bool isLoadingUserAllergens = true;

  @override
  void initState() {
    super.initState();
    _loadUserAllergens();
    if (widget.isOCRAnalysis &&
        widget.currentAllergens.isNotEmpty &&
        widget.productName != null) {
      loadAlternativeProducts();
    }
  }

  // Load user's allergens from Firebase
  Future<void> _loadUserAllergens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        Set<String> allergens = {};
        for (QueryDocumentSnapshot doc in allergenSnapshot.docs) {
          String allergenName = doc['name'].toString().toLowerCase();
          allergens.add(allergenName);
        }

        setState(() {
          userAllergens = allergens;
          isLoadingUserAllergens = false;
        });
      } else {
        setState(() {
          isLoadingUserAllergens = false;
        });
      }
    } catch (e) {
      print('Error loading user allergens: $e');
      setState(() {
        isLoadingUserAllergens = false;
      });
    }
  }

  Color _getAllergenColor(AllergenInfo allergen) {
    if (isLoadingUserAllergens) {
      return Colors.grey;
    }

    String allergenName = allergen.name.toLowerCase();

    bool userHasAllergen =
        userAllergens.contains(allergenName) ||
        userAllergens.any(
          (userAllergen) =>
              userAllergen.contains(allergenName) ||
              allergenName.contains(userAllergen),
        );

    return userHasAllergen ? Colors.red : AppColors.primary;
  }

  Color _getAllergenBackgroundColor(AllergenInfo allergen) {
    if (isLoadingUserAllergens) {
      return Colors.white;
    }

    String allergenName = allergen.name.toLowerCase();

    bool userHasAllergen =
        userAllergens.contains(allergenName) ||
        userAllergens.any(
          (userAllergen) =>
              userAllergen.contains(allergenName) ||
              allergenName.contains(userAllergen),
        );

    return userHasAllergen ? Colors.red.withOpacity(0.1) : Colors.white;
  }

  Color _getAllergenBorderColor(AllergenInfo allergen) {
    if (isLoadingUserAllergens) {
      return Colors.grey.withOpacity(0.3);
    }

    String allergenName = allergen.name.toLowerCase();

    bool userHasAllergen =
        userAllergens.contains(allergenName) ||
        userAllergens.any(
          (userAllergen) =>
              userAllergen.contains(allergenName) ||
              allergenName.contains(userAllergen),
        );

    // If user has the allergen, return red border
    // If user doesn't have the allergen, return transparent border
    return userHasAllergen ? Colors.red.withOpacity(0.3) : Colors.transparent;
  }

  Future<void> loadAlternativeProducts() async {
    if (widget.productName == null || widget.productName!.isEmpty) return;

    setState(() {
      isLoadingAlternatives = true;
    });

    try {
      final alternatives = await fetchAlternativeProducts(
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

  Future<List<AlternativeProduct>> fetchAlternativeProducts(
    String productName,
    List<AllergenInfo> allergens,
  ) async {
    try {
      String searchTerm = extractCategory(productName);
      List<String> allergenCodes = getAllergenCodes(allergens);

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
          if (product['product_name']?.toString().toLowerCase() ==
              productName.toLowerCase())
            continue;

          if (isProductSafe(product, allergenCodes)) {
            alternatives.add(
              AlternativeProduct(
                name: product['product_name'] ?? 'Unknown Product',
                brand: product['brands'] ?? '',
                imageUrl: product['image_url'] ?? '',
                allergens: extractProductAllergens(product),
              ),
            );
          }

          if (alternatives.length >= 3) break;
        }

        return alternatives;
      }
    } catch (e) {
      print('Error fetching alternatives: $e');
    }

    return [];
  }

  String extractCategory(String productName) {
    String name = productName.toLowerCase();

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

    if (name.contains('milk') ||
        name.contains('dairy') ||
        name.contains('gatas')) {
      return 'milk dairy';
    }

    if (name.contains('bread') ||
        name.contains('tinapay') ||
        name.contains('pandesal') ||
        name.contains('wheat') ||
        name.contains('loaf')) {
      return 'bread baked goods';
    }

    if (name.contains('cookie') ||
        name.contains('biscuit') ||
        name.contains('galletas') ||
        name.contains('crackers')) {
      return 'cookies biscuits';
    }

    if (name.contains('chocolate') ||
        name.contains('choco') ||
        name.contains('cocoa') ||
        name.contains('tsokolate')) {
      return 'chocolate';
    }

    if (name.contains('cheese') ||
        name.contains('keso') ||
        name.contains('queso')) {
      return 'cheese';
    }

    if (name.contains('yogurt') ||
        name.contains('yoghurt') ||
        name.contains('greek yogurt')) {
      return 'yogurt';
    }

    if (name.contains('cereal') ||
        name.contains('cornflakes') ||
        name.contains('oats') ||
        name.contains('granola') ||
        name.contains('muesli')) {
      return 'cereal breakfast';
    }

    if (name.contains('chips') ||
        name.contains('snack') ||
        name.contains('crackers') ||
        name.contains('nuts') ||
        name.contains('pretzels')) {
      return 'snacks chips';
    }

    if (name.contains('rice') ||
        name.contains('bigas') ||
        name.contains('kanin') ||
        name.contains('fried rice')) {
      return 'rice';
    }

    if (name.contains('canned') ||
        name.contains('sardines') ||
        name.contains('corned beef') ||
        name.contains('lata')) {
      return 'canned goods';
    }

    if (name.contains('sauce') ||
        name.contains('ketchup') ||
        name.contains('soy sauce') ||
        name.contains('vinegar') ||
        name.contains('sarsa')) {
      return 'sauce condiments';
    }

    if (name.contains('juice') ||
        name.contains('drink') ||
        name.contains('soda') ||
        name.contains('water') ||
        name.contains('coffee') ||
        name.contains('tea')) {
      return 'beverages drinks';
    }

    if (name.contains('meat') ||
        name.contains('beef') ||
        name.contains('pork') ||
        name.contains('chicken') ||
        name.contains('karne')) {
      return 'meat products';
    }

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

  List<String> getAllergenCodes(List<AllergenInfo> allergens) {
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

  bool isProductSafe(
    Map<String, dynamic> product,
    List<String> avoidAllergens,
  ) {
    String allergens = product['allergens'] ?? '';
    String allergensLower = allergens.toLowerCase();

    for (String allergen in avoidAllergens) {
      if (allergensLower.contains(allergen)) {
        return false;
      }
    }

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

  List<String> extractProductAllergens(Map<String, dynamic> product) {
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
              if (widget.isUpdatingAllergens || isLoadingUserAllergens)
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
            Wrap(
              spacing: 12,
              runSpacing: 16,
              children:
                  widget.currentAllergens.map((allergen) {
                    Color allergenColor = _getAllergenColor(allergen);
                    Color backgroundColor = _getAllergenBackgroundColor(
                      allergen,
                    );
                    Color borderColor = _getAllergenBorderColor(allergen);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            border: Border.all(color: borderColor, width: 1.5),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: FaIcon(
                              allergen.iconData,
                              color: AppColors.primaryColor3,
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        SizedBox(
                          width: 80,
                          child: Text(
                            allergen.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: allergenColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    spreadRadius: 1,
                    offset: Offset(0, 3),
                  ),
                ],
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
              buildAlternativesSection()
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      spreadRadius: 1,
                      offset: Offset(0, 3),
                    ),
                  ],
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

  Widget buildAlternativesSection() {
    if (alternativeProducts.isNotEmpty) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              alternativeProducts.map((product) {
                return Container(
                  width: 140,
                  margin: EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: Offset(0, 3),
                            ),
                          ],
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
                                      return buildPlaceholderImage();
                                    },
                                  )
                                  : buildPlaceholderImage(),
                        ),
                      ),
                      SizedBox(height: 12),
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
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    } else if (isLoadingAlternatives) {
      return Row(
        children: List.generate(3, (index) {
          return Container(
            margin: EdgeInsets.only(right: 16),
            width: 140,
            child: Column(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Container(height: 16, width: 80, color: Colors.grey[200]),
                SizedBox(height: 4),
                Container(height: 12, width: 60, color: Colors.grey[200]),
              ],
            ),
          );
        }),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 32,
                color: Colors.blue[300],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Alternative Products Found',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find safe alternatives matching your criteria',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }
  }

  Widget buildPlaceholderImage() {
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
}

class AlternativeProduct {
  final String name;
  final String brand;
  final String imageUrl;
  final List<String> allergens;

  AlternativeProduct({
    required this.name,
    required this.brand,
    required this.imageUrl,
    required this.allergens,
  });
}
