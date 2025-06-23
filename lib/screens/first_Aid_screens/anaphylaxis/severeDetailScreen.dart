import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

import '../../emergency/emergency_screen.dart';

class SevereEmergencyPageViewScreen extends StatefulWidget {
  final int initialPage;

  SevereEmergencyPageViewScreen({required this.initialPage});

  @override
  _SevereEmergencyPageViewScreenState createState() =>
      _SevereEmergencyPageViewScreenState();
}

class _SevereEmergencyPageViewScreenState
    extends State<SevereEmergencyPageViewScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late EmergencyService emergencyService;
  bool _isLoading = true;

  Future<void> _initializeEmergencyService() async {
    emergencyService = EmergencyService();
    await emergencyService.initialize();
    setState(() => _isLoading = false);
  }

  final List<EmergencyAction> emergencyActions = [
    EmergencyAction(1, "Symptoms"),
    EmergencyAction(2, "Lay the  victim flat"),
    EmergencyAction(3, "Recovery position"),
    EmergencyAction(4, "Position"),
    EmergencyAction(5, "Remove allergen"),
    EmergencyAction(6, "How to give EpiPen"),
    EmergencyAction(7, "How to give Anapen"),
    EmergencyAction(8, "Call for Help"),
    EmergencyAction(9, "Repeat dose"),
    EmergencyAction(10, "Asthma medication"),
  ];
  double _dragPosition = 0.0;
  bool _isDragging = false;
  static const double _dragThreshold =
      150.0; // Distance needed to trigger navigation
  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _initializeEmergencyService(); // Added this line
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  EmergencyContent _getContentForAction(int actionNumber) {
    // Since all content is embedded in the images, we just return empty content
    return EmergencyContent();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (details.delta.dy < 0) {
        _dragPosition = (_dragPosition - details.delta.dy).clamp(
          0.0,
          _dragThreshold,
        );
      } else if (_dragPosition > 0) {
        _dragPosition = (_dragPosition - details.delta.dy).clamp(
          0.0,
          _dragThreshold,
        );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) async {
    setState(() {
      _isDragging = false;
    });

    if (_dragPosition >= _dragThreshold) {
      // Navigate to emergency screen
      emergencyService.startEmergencyCallFromUI(context);
    }

    // Reset position with animation
    setState(() {
      _dragPosition = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.defaultbackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Anaphylaxis',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: emergencyActions.length,
                itemBuilder: (context, index) {
                  return _buildDetailPage(emergencyActions[index]);
                },
              ),
            ),
            // Page Indicators
            Container(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _currentPage == index
                              ? AppColors.primary
                              : AppColors.lightGray,
                    ),
                  );
                }),
              ),
            ),

            // Emergency Button - Draggable
            Container(
              padding: EdgeInsets.all(20),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: _isDragging ? 0 : 300),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(0, -_dragPosition, 0),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color:
                        _dragPosition > 0
                            ? Color(0xFFc44537).withOpacity(
                              0.9 + (_dragPosition / _dragThreshold) * 0.1,
                            )
                            : Color(0xFFc44537),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFc44537).withOpacity(
                          0.3 + (_dragPosition / _dragThreshold) * 0.2,
                        ),
                        blurRadius: 10 + (_dragPosition / _dragThreshold) * 5,
                        offset: Offset(
                          0,
                          4 + (_dragPosition / _dragThreshold) * 2,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress indicators
                      if (_dragPosition > 0)
                        Container(
                          margin: EdgeInsets.only(bottom: 8),
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _dragPosition / _dragThreshold,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedRotation(
                            duration: Duration(milliseconds: 200),
                            turns: _dragPosition > 0 ? 0.5 : 0,
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _dragPosition >= _dragThreshold
                                ? "Release to Emergency!"
                                : "Pull to access an Emergency",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Visual feedback for drag progress
                      if (_dragPosition > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "${(_dragPosition / _dragThreshold * 100).round()}%",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPage(EmergencyAction action) {
    final content = _getContentForAction(action.number);

    return Container(
      color: AppColors.defaultbackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Title
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        action.number.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      action.text,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textBlack,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Section
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _buildContentSection(content, action.number),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(EmergencyContent content, int actionNumber) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 20),

          // Full Image Display - All content is in the image
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/anaphylaxis/act$actionNumber.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image fails to load
                  return Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIllustrationIcon(actionNumber),
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Action $actionNumber Image',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getIllustrationIcon(int actionNumber) {
    switch (actionNumber) {
      case 1:
        return Icons.people; // Comfort/assistance
      case 2:
        return Icons.airline_seat_recline_extra; // Rest
      case 3:
        return Icons.medical_services; // Medicine/EpiPen
      case 4:
        return Icons.wash; // Washing hands/cleaning
      case 5:
        return Icons.monitor_heart; // Vital signs
      default:
        return Icons.people;
    }
  }
}

// Data Models
class EmergencyAction {
  final int number;
  final String text;

  EmergencyAction(this.number, this.text);
}

class EmergencyContent {
  EmergencyContent();
}
