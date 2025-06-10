import 'package:flutter/material.dart';

import 'EmergencyDetailScreen.dart';

class EmergencyListScreen extends StatelessWidget {
  final List<EmergencyAction> emergencyActions = [
    EmergencyAction(1, "Assist victim to be comfortable"),
    EmergencyAction(2, "Stay in the victim, ensure rest"),
    EmergencyAction(3, "Assist with prescribed medicine"),
    EmergencyAction(4, "If reaction is caused by a chemical or liquid"),
    EmergencyAction(5, "Monitor vital signs regularly"),
  ];

  void _navigateToPageView(BuildContext context, int actionNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EmergencyPageViewScreen(
              initialPage: actionNumber - 1, // Convert to 0-based index
            ),
      ),
    );
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
            color: Color(0xFF007AFF),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mild to Moderate',
          style: TextStyle(
            color: Color(0xFF007AFF),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E5E7)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            // Container(
            //   padding: EdgeInsets.all(20),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black.withOpacity(0.05),
            //         blurRadius: 10,
            //         offset: Offset(0, 2),
            //       ),
            //     ],
            //   ),
            //   child: Row(
            //     children: [

            //     ],
            //   ),
            // ),

            // Actions List
            Expanded(
              child: Container(
                color: Color(0xFFf8f9fc),
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

            // Emergency Button
            Container(
              padding: EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () {
                  // Handle emergency action
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Color(0xFFc44537),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFc44537).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Pull to access an Emergency",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: () => _navigateToPageView(context, action.number),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(0xFF2c5aa0),
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
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}
