import 'dart:io';
import 'dart:ui';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/ingredientmodal.dart';
import 'package:allergen/screens/scan_screen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ResultScreen extends StatefulWidget {
  final File image;
  final String dishName;
  final String description;
  final List<String> ingredients;
  final List<AllergenInfo> allergens;
  final Function(List<String>) onIngredientsChanged;

  const ResultScreen({
    Key? key,
    required this.image,
    required this.dishName,
    required this.description,
    required this.ingredients,
    required this.allergens,
    required this.onIngredientsChanged,
  }) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> currentIngredients;
  late List<AllergenInfo> currentAllergens;
  bool isEditing = false;
  bool isUpdatingAllergens = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    currentIngredients = List.from(widget.ingredients);
    currentAllergens = List.from(widget.allergens);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  Future<void> _saveChanges() async {
    setState(() {
      isEditing = false;
      isUpdatingAllergens = true;
    });

    // Update allergens based on new ingredients
    await _updateAllergens();

    // Notify parent of ingredient changes
    await widget.onIngredientsChanged(currentIngredients);

    setState(() {
      isUpdatingAllergens = false;
    });
  }

  Future<void> _updateAllergens() async {
    // Simple allergen detection map
    Map<String, Map<String, dynamic>> allergenMap = {
      'milk': {
        'level': 'severe',
        'symptoms': ['stomach pain', 'bloating', 'diarrhea'],
      },
      'dairy': {
        'level': 'severe',
        'symptoms': ['stomach pain', 'bloating', 'diarrhea'],
      },
      'eggs': {
        'level': 'severe',
        'symptoms': ['skin rash', 'nausea', 'vomiting'],
      },
      'egg': {
        'level': 'severe',
        'symptoms': ['skin rash', 'nausea', 'vomiting'],
      },
      'peanuts': {
        'level': 'severe',
        'symptoms': ['difficulty breathing', 'swelling', 'anaphylaxis'],
      },
      'peanut': {
        'level': 'severe',
        'symptoms': ['difficulty breathing', 'swelling', 'anaphylaxis'],
      },
      'nuts': {
        'level': 'moderate',
        'symptoms': ['throat swelling', 'hives', 'difficulty breathing'],
      },
      'wheat': {
        'level': 'moderate',
        'symptoms': ['bloating', 'abdominal pain', 'fatigue'],
      },
      'gluten': {
        'level': 'moderate',
        'symptoms': ['bloating', 'abdominal pain', 'fatigue'],
      },
      'soy': {
        'level': 'mild',
        'symptoms': ['mild nausea', 'skin irritation'],
      },
      'fish': {
        'level': 'severe',
        'symptoms': ['hives', 'swelling', 'difficulty breathing'],
      },
      'shellfish': {
        'level': 'severe',
        'symptoms': ['hives', 'swelling', 'difficulty breathing'],
      },
      'sesame': {
        'level': 'mild',
        'symptoms': ['mild skin reaction', 'digestive discomfort'],
      },
    };

    List<AllergenInfo> detectedAllergens = [];

    for (String ingredient in currentIngredients) {
      String lowerIngredient = ingredient.toLowerCase();

      for (String allergen in allergenMap.keys) {
        if (lowerIngredient.contains(allergen)) {
          bool alreadyExists = detectedAllergens.any(
            (a) => a.name.toLowerCase() == allergen,
          );

          if (!alreadyExists) {
            detectedAllergens.add(
              AllergenInfo(
                name: allergen.capitalize(),
                riskLevel: allergenMap[allergen]!['level'],
                symptoms: allergenMap[allergen]!['symptoms'],
              ),
            );
          }
        }
      }
    }

    setState(() {
      currentAllergens = detectedAllergens;
    });
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) {
        String newIngredient = '';
        return AlertDialog(
          title: Text('Add Ingredient'),
          content: TextField(
            onChanged: (value) => newIngredient = value,
            decoration: InputDecoration(
              hintText: 'Enter ingredient name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newIngredient.trim().isNotEmpty) {
                  setState(() {
                    currentIngredients.add(newIngredient.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      currentIngredients.removeAt(index);
    });
  }

  Color _getIngredientColor(String ingredient) {
    String lowerIngredient = ingredient.toLowerCase();

    // Check severe allergens (red)
    List<String> severeAllergens = [
      'milk',
      'dairy',
      'eggs',
      'egg',
      'peanuts',
      'peanut',
      'fish',
      'shellfish',
    ];
    for (String allergen in severeAllergens) {
      if (lowerIngredient.contains(allergen)) return Colors.red;
    }

    // Check moderate allergens (yellow)
    List<String> moderateAllergens = ['nuts', 'wheat', 'gluten'];
    for (String allergen in moderateAllergens) {
      if (lowerIngredient.contains(allergen)) return Colors.orange;
    }

    // Check mild allergens (green)
    List<String> mildAllergens = ['soy', 'sesame'];
    for (String allergen in mildAllergens) {
      if (lowerIngredient.contains(allergen)) return Colors.green;
    }

    // Safe ingredient (grey)
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Result'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Image.asset('assets/images/history.png', width: 40, height: 40),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.image,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dishName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (currentAllergens.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/emergency.png',
                                width: 20,
                                height: 20,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Allergen detected',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FirstAidScreen()),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/first_aid.png',
                                width: 20,
                                height: 20,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Learn about first aid',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: [Tab(text: 'Allergen'), Tab(text: 'Description')],
            labelColor: AppColors.textBlack,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primary,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildAllergenTab(), _buildDescriptionTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenTab() {
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
              if (isUpdatingAllergens)
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
          if (currentAllergens.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  currentAllergens.map((allergen) {
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
          Text(
            'Alternative Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Row(
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
                      Icon(Icons.image, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Alternative ${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Coming soon',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scanned Ingredients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _toggleEdit,
                icon: Container(
                  padding: EdgeInsets.all(8),
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
          SizedBox(height: 12),
          Container(
            width: 400,
            height: 100,
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ), // Increased padding
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color Legend:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildColorLegendItem(Colors.grey, 'Safe'),
                      SizedBox(width: 20),
                      _buildColorLegendItem(Colors.green, 'Mild'),
                      SizedBox(width: 20),
                      _buildColorLegendItem(Colors.orange, 'Moderate'),
                      SizedBox(width: 20),
                      _buildColorLegendItem(Colors.red, 'Severe'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.all(16),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textBlack,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Simplified ingredient chips
                    for (int i = 0; i < currentIngredients.length; i++)
                      _buildIngredientChip(currentIngredients[i], i),

                    // Add button
                    if (isEditing)
                      GestureDetector(
                        onTap: _addIngredient,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isEditing = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
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

  Widget _buildIngredientChip(String ingredient, int index) {
    Color chipColor = _getIngredientColor(ingredient);
    bool isSafe = chipColor == Colors.grey;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true, // optional: allows full height
          shape: RoundedRectangleBorder(
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
              Text(
                ingredient,
                style: TextStyle(
                  fontSize: 13,
                  color: isSafe ? Colors.black87 : Colors.white,
                  fontWeight: isSafe ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
              if (!isEditing) ...[
                SizedBox(width: 6),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isSafe ? Colors.black54 : Colors.white70,
                ),
              ],
              if (isEditing) ...[
                SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _removeIngredient(index),
                  child: Container(
                    padding: EdgeInsets.all(2),
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

  Widget _buildColorLegendItem(Color color, String label) {
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
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        SizedBox(width: 6),
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
}

// Extension to capitalize first letter
extension StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }
}
