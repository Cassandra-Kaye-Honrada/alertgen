import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

import '../emergencyScreen.dart';
import 'severeDetailScreen.dart';

class SevereEmergencyListScreen extends StatefulWidget {
  @override
  _SevereEmergencyListScreenState createState() =>
      _SevereEmergencyListScreenState();
}

class _SevereEmergencyListScreenState extends State<SevereEmergencyListScreen> {
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

  void _navigateToPageView(BuildContext context, int actionNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                SevereEmergencyPageViewScreen(initialPage: actionNumber - 1),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Only allow upward dragging (negative delta)
      if (details.delta.dy < 0) {
        _dragPosition = (_dragPosition - details.delta.dy).clamp(
          0.0,
          _dragThreshold,
        );
      } else if (_dragPosition > 0) {
        // Allow downward movement only if already dragged up
        _dragPosition = (_dragPosition - details.delta.dy).clamp(
          0.0,
          _dragThreshold,
        );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    if (_dragPosition >= _dragThreshold) {
      // Navigate to emergency screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EmergencyScreen()),
      );
    }

    // Reset position with animation
    setState(() {
      _dragPosition = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF2F9FF),
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
            // Actions List
            Expanded(
              child: Container(
                color: AppColors.defaultbackground,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      "ACTIONS",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 15),
                    Expanded(
                      child: ListView.builder(
                        itemCount: emergencyActions.length,
                        itemBuilder: (context, index) {
                          return _buildActionItem(
                            context,
                            emergencyActions[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
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

  Widget _buildActionItem(BuildContext context, EmergencyAction action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: GestureDetector(
          onTap: () => _navigateToPageView(context, action.number),
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
                    fontSize: 16,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder for Severe Emergency Screen
