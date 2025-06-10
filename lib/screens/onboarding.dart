import 'package:allergen/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String username = '';
  Set<String> selectedAllergens = {};
  Map<String, double> allergenSeverity = {};
  TextEditingController searchController = TextEditingController();
  List<String> filteredAllergens = [];

  final List<String> commonAllergens = [
    'Shellfish',
    'Sesame',
    'Egg',
    'Peanut',
    'Fish',
    'Milk',
    'Soybean',
    'Shrimp',
    'Nuts',
    'Wheat',
  ];

  @override
  void initState() {
    super.initState();
    filteredAllergens = List.from(commonAllergens);
    fetchUsername();
    loadExistingAllergens();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (searchController.text.isEmpty) {
        filteredAllergens = List.from(commonAllergens);
      } else {
        filteredAllergens =
            commonAllergens
                .where(
                  (allergen) => allergen.toLowerCase().contains(
                    searchController.text.toLowerCase(),
                  ),
                )
                .toList();
      }
    });
  }

  Future<void> fetchUsername() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
      setState(() {
        username = 'User';
      });
    }
  }

  Future<void> loadExistingAllergens() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot profileSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        setState(() {
          selectedAllergens.clear();
          allergenSeverity.clear();

          for (QueryDocumentSnapshot doc in profileSnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String allergenName = data['name'] ?? '';
            double severity = (data['severity'] ?? 0.5).toDouble();

            if (allergenName.isNotEmpty) {
              selectedAllergens.add(allergenName);
              allergenSeverity[allergenName] = severity;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading existing allergens: $e');
    }
  }

  void toggleAllergen(String allergen) {
    setState(() {
      if (selectedAllergens.contains(allergen)) {
        selectedAllergens.remove(allergen);
        allergenSeverity.remove(allergen);
      } else {
        selectedAllergens.add(allergen);
        allergenSeverity[allergen] = 0.5; // Default to moderate
      }
    });
  }

  Color _getSeverityColor(double severity) {
    if (severity < 0.33) return Colors.green.shade300; // Mild
    if (severity < 0.67) return Colors.orange.shade300; // Moderate
    return Colors.red.shade300; // Severe
  }

  void showAllergenModal(String allergen, {bool isManualAdd = false}) {
    double currentSeverity = allergenSeverity[allergen] ?? 0.5;
    TextEditingController manualAllergenController = TextEditingController();

    if (isManualAdd) {
      manualAllergenController.text = allergen;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isManualAdd) ...[
                        Text(
                          'Manually add your allergen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: manualAllergenController,
                          decoration: InputDecoration(
                            hintText: 'Enter allergen name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF0891B2)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                      ] else ...[
                        Row(
                          children: [
                            Text(
                              allergen,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                      ],

                      Text(
                        'How severe is this allergen reaction?',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      SizedBox(height: 24),

                      // Severity Slider
                      Container(
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 8,
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: 20,
                                ),
                                activeTrackColor: _getSliderColor(
                                  currentSeverity,
                                ),
                                inactiveTrackColor: Colors.grey.shade300,
                                thumbColor: _getSliderColor(currentSeverity),
                                overlayColor: _getSliderColor(
                                  currentSeverity,
                                ).withOpacity(0.2),
                              ),
                              child: Slider(
                                value: currentSeverity,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (value) {
                                  setModalState(() {
                                    currentSeverity = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mild',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Moderate',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Severe',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Drag to edit',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            String finalAllergen =
                                isManualAdd
                                    ? manualAllergenController.text.trim()
                                    : allergen;

                            if (finalAllergen.isNotEmpty) {
                              setState(() {
                                selectedAllergens.add(finalAllergen);
                                allergenSeverity[finalAllergen] =
                                    currentSeverity;

                                // Add to common allergens list if it's a manual entry and not already there
                                if (isManualAdd &&
                                    !commonAllergens.contains(finalAllergen)) {
                                  commonAllergens.add(finalAllergen);
                                  filteredAllergens = List.from(
                                    commonAllergens,
                                  );
                                }
                              });
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0891B2),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isManualAdd ? 'Save Allergen' : 'Save Selection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Color _getSliderColor(double value) {
    if (value < 0.33) return Colors.green;
    if (value < 0.67) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Back',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome ${username.isNotEmpty ? username : 'User'}!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Pick what allergen you have',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              'We want to recommend the best option. If you don\'t have any allergen just continue.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            SizedBox(height: 24),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search for Allergens',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            SizedBox(height: 32),

            // Allergen Chips
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      filteredAllergens.map((allergen) {
                        bool isSelected = selectedAllergens.contains(allergen);
                        Color chipColor =
                            isSelected
                                ? _getSeverityColor(
                                  allergenSeverity[allergen] ?? 0.5,
                                )
                                : Colors.grey.shade200;

                        return GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              showAllergenModal(allergen);
                            } else {
                              toggleAllergen(allergen);
                              showAllergenModal(allergen);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.green,
                                        width: 2,
                                      )
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 8),
                                ],
                                Text(
                                  allergen,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Bottom Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showAllergenModal('', isManualAdd: true),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF0891B2)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Not here? Manually add',
                      style: TextStyle(
                        color: Color(0xFF0891B2),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Save allergens to Firebase subcollection
                      try {
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          // Create a batch to save multiple allergens
                          WriteBatch batch = FirebaseFirestore.instance.batch();

                          // Reference to the profile subcollection
                          CollectionReference profileRef = FirebaseFirestore
                              .instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('profile');

                          // First, delete existing allergens in the profile subcollection
                          QuerySnapshot existingAllergens =
                              await profileRef
                                  .where('type', isEqualTo: 'allergen')
                                  .get();
                          for (QueryDocumentSnapshot doc
                              in existingAllergens.docs) {
                            batch.delete(doc.reference);
                          }

                          // Add new allergens to the profile subcollection
                          for (String allergen in selectedAllergens) {
                            DocumentReference allergenDoc = profileRef.doc();
                            batch.set(allergenDoc, {
                              'name': allergen,
                              'severity': allergenSeverity[allergen] ?? 0.5,
                              'createdAt': FieldValue.serverTimestamp(),
                              'type': 'allergen',
                            });
                          }

                          await batch.commit();

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => Homescreen()),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Allergens saved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving allergens: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0891B2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
