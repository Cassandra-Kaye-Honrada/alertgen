import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:allergen/styleguide.dart';

class AllergenProfileScreen extends StatefulWidget {
  const AllergenProfileScreen({Key? key}) : super(key: key);

  @override
  State<AllergenProfileScreen> createState() => _AllergenProfileScreenState();
}

class _AllergenProfileScreenState extends State<AllergenProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  Set<String> selectedAllergens = {};
  Map<String, double> allergenSeverity = {};
  List<String> filteredAllergens = [];
  bool isLoading = true;
  bool isGeneralProductAllergensEnabled = true;

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
    _loadUserAllergens();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredAllergens = List.from(commonAllergens);
      } else {
        filteredAllergens =
            commonAllergens
                .where(
                  (allergen) => allergen.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ),
                )
                .toList();
      }
    });
  }

  Future<void> _loadUserAllergens() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        setState(() {
          selectedAllergens.clear();
          allergenSeverity.clear();

          for (QueryDocumentSnapshot doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String allergenName = data['name'] ?? '';
            double severity = (data['severity'] ?? 0.5).toDouble();

            if (allergenName.isNotEmpty) {
              selectedAllergens.add(allergenName);
              allergenSeverity[allergenName] = severity;

              if (!commonAllergens.contains(allergenName)) {
                commonAllergens.add(allergenName);
                filteredAllergens = List.from(commonAllergens);
              }
            }
          }
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user allergens: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void toggleAllergen(String allergen) {
    setState(() {
      if (selectedAllergens.contains(allergen)) {
        selectedAllergens.remove(allergen);
        allergenSeverity.remove(allergen);
      } else {
        selectedAllergens.add(allergen);
        allergenSeverity[allergen] = 0.5;
      }
    });
  }

  Color _getSeverityColor(double severity) {
    if (severity < 0.33) return const Color(0xFF10B981); // Green
    if (severity < 0.67) return const Color(0xFFF59E0B); // Orange
    return const Color(0xFFEF4444); // Red
  }

  String _getSeverityLabel(double severity) {
    if (severity < 0.33) return 'Mild';
    if (severity < 0.67) return 'Moderate';
    return 'Severe';
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
      shape: const RoundedRectangleBorder(
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
                        const Text(
                          'Manually add your allergen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: manualAllergenController,
                          decoration: InputDecoration(
                            hintText: 'Enter allergen name',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontFamily: 'Poppins',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor3,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Row(
                          children: [
                            Text(
                              allergen,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      const Text(
                        'How severe is this allergen reaction?',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 20,
                                ),
                                activeTrackColor: _getSeverityColor(
                                  currentSeverity,
                                ),
                                inactiveTrackColor: Colors.grey.shade300,
                                thumbColor: _getSeverityColor(currentSeverity),
                                overlayColor: _getSeverityColor(
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
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mild',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  'Moderate',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  'Severe',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Drag to edit',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalAllergen =
                                isManualAdd
                                    ? manualAllergenController.text.trim()
                                    : allergen;

                            if (finalAllergen.isNotEmpty) {
                              setState(() {
                                selectedAllergens.add(finalAllergen);
                                allergenSeverity[finalAllergen] =
                                    currentSeverity;

                                if (isManualAdd &&
                                    !commonAllergens.contains(finalAllergen)) {
                                  commonAllergens.add(finalAllergen);
                                  filteredAllergens = List.from(
                                    commonAllergens,
                                  );
                                }
                              });

                              await _saveAllergenToFirebase(
                                finalAllergen,
                                currentSeverity,
                              );
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor3,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            isManualAdd
                                ? 'Add Allergen'
                                : selectedAllergens.contains(allergen)
                                ? 'Update Severity'
                                : 'Add Allergen',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
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

  Future<void> _saveAllergenToFirebase(
    String allergenName,
    double severity,
  ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot existingAllergen =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergenName)
                .get();

        if (existingAllergen.docs.isNotEmpty) {
          await existingAllergen.docs.first.reference.update({
            'severity': severity,
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .add({
                'name': allergenName,
                'severity': severity,
                'type': 'allergen',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$allergenName saved successfully!',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.primaryColor3,
          ),
        );
      }
    } catch (e) {
      print('Error saving allergen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error saving allergen. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRemoveConfirmation(String allergenName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Allergen',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          content: Text(
            'Are you sure you want to remove "$allergenName" from your allergen profile?',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAllergen(allergenName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeAllergen(String allergenName) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenDocs =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergenName)
                .get();

        for (QueryDocumentSnapshot doc in allergenDocs.docs) {
          await doc.reference.delete();
        }

        setState(() {
          selectedAllergens.remove(allergenName);
          allergenSeverity.remove(allergenName);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allergen removed from your profile',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Color(0xFF0EA5E9),
          ),
        );
      }
    } catch (e) {
      print('Error removing allergen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error removing allergen. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Allergen Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // General Product Allergens Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'General Product Allergens',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enable the filter to view all allergens including those affecting you.',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isGeneralProductAllergensEnabled,
                      onChanged: (value) {
                        setState(() {
                          isGeneralProductAllergensEnabled = value;
                        });
                      },
                      activeColor: const Color(0xFF0EA5E9),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title and Description
              const Text(
                'Pick what allergen you have',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),

              const SizedBox(height: 16),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search for Allergens',
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // "Not here? Manually add" button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showAllergenModal('', isManualAdd: true),
                  child: const Text(
                    'Not here? Manually add',
                    style: TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Active Allergens Display
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
                )
              else if (selectedAllergens.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No allergens added yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add allergens to help us recommend better products for you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children:
                      selectedAllergens.map((allergen) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => showAllergenModal(allergen),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            allergen,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Poppins',
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getSeverityColor(
                                                allergenSeverity[allergen] ??
                                                    0.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              _getSeverityLabel(
                                                allergenSeverity[allergen] ??
                                                    0.5,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed:
                                          () =>
                                              _showRemoveConfirmation(allergen),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFEF4444),
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
