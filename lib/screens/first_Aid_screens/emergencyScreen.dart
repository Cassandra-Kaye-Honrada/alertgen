import 'package:flutter/material.dart';

class EmergencyScreen extends StatefulWidget {
  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int currentStep = 1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Simulate step progression
    _simulateSteps();
  }

  void _simulateSteps() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          currentStep = 2;
        });
      }
    });

    Future.delayed(Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          currentStep = 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black54,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Emergency',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Title
              Text(
                'Calling emergency...',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),

              // Subtitle
              Text(
                'Please stand by, we are currently requesting\nfor help. Your emergency contacts and nearby\nrescue services would see your call for help',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulse rings
                            for (int i = 0; i < 3; i++)
                              Transform.scale(
                                scale: _pulseAnimation.value + (i * 0.2),
                                child: Container(
                                  width: 280 - (i * 40),
                                  height: 280 - (i * 40),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _getStepColor().withOpacity(
                                        0.3 - (i * 0.1),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),

                            // Main circle with gradient
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _getStepColor().withOpacity(0.8),
                                    _getStepColor(),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStepColor().withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '0$currentStep',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStepColor() {
    switch (currentStep) {
      case 1:
        return Color(0xFFFF6B6B); // Red-orange
      case 2:
        return Color(0xFFFF9F40); // Orange
      case 3:
        return Color(0xFFFF6B6B); // Red-orange
      default:
        return Color(0xFFFF6B6B);
    }
  }
}
