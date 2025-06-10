import 'package:allergen/screens/login.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // State variables for implicit animations
  bool _logoVisible = false;
  bool _wavesVisible = false;
  bool _iconsVisible = false;
  bool _titleVisible = false;
  bool _subtitleVisible = false;
  bool _scanningVisible = false;

  double _logoScale = 0.0;
  double _logoOpacity = 0.0;
  double _waveScale = 0.5;
  double _rotation = 0.0;
  double _waveOpacity = 0.0;

  // Animation controllers for smooth continuous animations
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers with different durations for variety
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: 12,
      ), // Slower rotation for ultra-smooth movement
    );

    _waveController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3), // Wave pulsing
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500), // Logo pulse
    );

    // Create smooth animations with better curves
    _waveAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Add listeners for smooth state updates - simplified rotation
    _rotationController.addListener(() {
      if (mounted) {
        setState(() {
          // Direct linear rotation for smoothest movement
          _rotation = _rotationController.value * 2 * math.pi;
        });
      }
    });

    _waveController.addListener(() {
      if (mounted) {
        setState(() {
          _waveScale = _wavesVisible ? _waveAnimation.value : 0.5;
        });
      }
    });

    _pulseController.addListener(() {
      if (mounted) {
        setState(() {
          // Subtle logo pulsing when visible
          if (_logoVisible) {
            _logoScale = _pulseAnimation.value;
          }
        });
      }
    });

    _startAnimationSequence();
    _navigateAfterDelay();
  }

  void _startAnimationSequence() async {
    // Logo entrance with bounce effect
    await Future.delayed(Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _logoVisible = true;
      _logoScale = 1.0;
      _logoOpacity = 1.0;
    });

    // Start subtle logo pulsing
    _pulseController.repeat(reverse: true);

    // Detection waves with staggered entrance
    await Future.delayed(Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _wavesVisible = true;
      _waveOpacity = 1.0;
    });

    // Start wave animation
    _waveController.repeat(reverse: true);

    // Orbiting icons with smooth entrance
    await Future.delayed(Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _iconsVisible = true;
    });

    // Start smooth rotation
    _rotationController.repeat();

    // Title with slide-up effect
    await Future.delayed(Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() {
      _titleVisible = true;
    });

    // Subtitle and scanning indicator
    await Future.delayed(Duration(milliseconds: 1600));
    if (!mounted) return;

    setState(() {
      _subtitleVisible = true;
      _scanningVisible = true;
    });
  }

  void _navigateAfterDelay() {
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        // Smooth fade out before navigation
        _rotationController.stop();
        _waveController.stop();
        _pulseController.stop();

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => LoginScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14B8A6), // Teal
              Color(0xFF0891B2), // Darker teal
              Color(0xFF1E40AF), // Blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Detection waves with improved animation
              AnimatedOpacity(
                duration: Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                opacity: _wavesVisible ? _waveOpacity : 0.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(4, (index) {
                    return _buildDetectionWave(index);
                  }),
                ),
              ),

              // Smoothly orbiting allergy icons
              AnimatedOpacity(
                duration: Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                opacity: _iconsVisible ? 1.0 : 0.0,
                child: Transform.rotate(
                  angle: _rotation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildOrbitingIcon('assets/allergens/Eggs.png', 0, 180),
                      _buildOrbitingIcon(
                        'assets/allergens/Gluten.png',
                        math.pi / 4,
                        150,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Milk.png',
                        math.pi / 2,
                        170,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Nuts.png',
                        3 * math.pi / 4,
                        160,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Cashew.png',
                        math.pi,
                        190,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Soy Bean.png',
                        5 * math.pi / 4,
                        165,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Fish.png',
                        3 * math.pi / 2,
                        175,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Crab.png',
                        7 * math.pi / 4,
                        155,
                      ),
                      _buildOrbitingIcon(
                        'assets/allergens/Sesame.png',
                        2 * math.pi,
                        185,
                      ),
                    ],
                  ),
                ),
              ),

              // Central logo with smooth animations
              AnimatedOpacity(
                duration: Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                opacity: _logoOpacity,
                child: AnimatedScale(
                  duration: Duration(milliseconds: 1500),
                  curve: Curves.elasticOut,
                  scale: _logoScale,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 1200),
                    curve: Curves.easeOutBack,
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle, // Changed to circle
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 25,
                          offset: Offset(0, 12),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // App title with smooth slide animation
              Positioned(
                top: MediaQuery.of(context).size.height * 0.65,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 1200),
                  curve: Curves.easeInOut,
                  opacity: _titleVisible ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: Duration(milliseconds: 1200),
                    curve: Curves.easeOutBack,
                    offset: _titleVisible ? Offset.zero : Offset(0, 0.3),
                    child: Text(
                      'AlertGen',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: Offset(0, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Subtitle with delayed entrance
              Positioned(
                top: MediaQuery.of(context).size.height * 0.72,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  opacity: _subtitleVisible ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: Duration(milliseconds: 1200),
                    curve: Curves.easeOutBack,
                    offset: _subtitleVisible ? Offset.zero : Offset(0, 0.3),
                    child: Text(
                      'Detecting Allergens Around You',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Scanning indicator with smooth entrance
              Positioned(
                bottom: 100,
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  opacity: _scanningVisible ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: Duration(milliseconds: 1200),
                    curve: Curves.easeOutBack,
                    offset: _scanningVisible ? Offset.zero : Offset(0, 0.5),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Initializing Detection...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildDetectionWave(int index) {
    double baseRadius = 100 + (index * 40);
    double delayFactor = index * 0.2;

    return AnimatedContainer(
      duration: Duration(milliseconds: 1200 + (index * 200)),
      curve: Curves.easeOutBack,
      width: _wavesVisible ? baseRadius * 2 * _waveScale : 0,
      height: _wavesVisible ? baseRadius * 2 * _waveScale : 0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.7 - (index * 0.15)),
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildOrbitingIcon(String assetPath, double angle, double radius) {
    double x = radius * math.cos(angle);
    double y = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(x, y),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: Offset(0, 3),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 5,
              offset: Offset(0, -2),
              spreadRadius: -2,
            ),
          ],
        ),
        child: AnimatedScale(
          duration: Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          scale: _iconsVisible ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Image.asset(
              assetPath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for AlertGen logo (unchanged)
class AlertGenLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint =
        Paint()
          ..color = Color(0xFF14B8A6)
          ..style = PaintingStyle.fill;

    // Draw the "A" shape with alert bubble
    Path path = Path();

    // Main "A" body - curved triangular shape
    path.moveTo(size.width * 0.1, size.height * 0.9);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.1,
      size.width * 0.9,
      size.height * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.7,
      size.width * 0.1,
      size.height * 0.9,
    );

    canvas.drawPath(path, paint);

    // Alert bubble
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.35),
      size.width * 0.15,
      Paint()..color = Colors.white,
    );

    // Exclamation mark
    Paint exclamationPaint =
        Paint()
          ..color = Color(0xFF14B8A6)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    // Exclamation line
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.27),
      Offset(size.width * 0.7, size.height * 0.37),
      exclamationPaint,
    );

    // Exclamation dot
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.42),
      2,
      Paint()..color = Color(0xFF14B8A6),
    );

    // Connection bubble
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.55),
      size.width * 0.08,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
