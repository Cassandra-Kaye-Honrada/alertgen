// screens/emergency/emergency_screen.dart
import 'package:allergen/screens/models/emergency_call_state.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/emergency_contact.dart';
import '../models/emergency_settings.dart';

class EmergencyScreen extends StatefulWidget {
  final List<EmergencyContact> emergencyContacts;
  final EmergencySettings emergencySettings;

  const EmergencyScreen({
    Key? key,
    required this.emergencyContacts,
    required this.emergencySettings,
  }) : super(key: key);

  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _dragController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _dragAnimation;

  final EmergencyService _emergencyService = EmergencyService();

  EmergencyCallState _currentState = EmergencyCallState.idle;
  EmergencyContact? _currentContact;
  int _countdown = 0;

  // Drag to cancel
  bool _isDragging = false;
  double _dragDistance = 0;
  static const double _cancelThreshold = 100.0;

  late StreamSubscription _stateSubscription;
  late StreamSubscription _contactSubscription;
  late StreamSubscription _countdownSubscription;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupStreams();
    _startEmergencyCall();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _dragController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _dragAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dragController, curve: Curves.easeInOut),
    );
  }

  void _setupStreams() {
    _stateSubscription = _emergencyService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });

        if (state == EmergencyCallState.completed ||
            state == EmergencyCallState.cancelled) {
          _navigateBack();
        }
      }
    });

    _contactSubscription = _emergencyService.currentContactStream.listen((
      contact,
    ) {
      if (mounted) {
        setState(() {
          _currentContact = contact;
        });
      }
    });

    _countdownSubscription = _emergencyService.countdownStream.listen((
      countdown,
    ) {
      if (mounted) {
        setState(() {
          _countdown = countdown;
        });
      }
    });
  }

  Future<void> _startEmergencyCall() async {
    await _emergencyService.startEmergencyCall(
      contacts: widget.emergencyContacts,
      settings: widget.emergencySettings,
    );
  }

  void _navigateBack() {
    Timer(Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.emergencySettings.enableDragToCancel) return;
    _isDragging = true;
    _dragController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.emergencySettings.enableDragToCancel) return;
    setState(() {
      _dragDistance += details.delta.dy;
      _dragDistance = _dragDistance.clamp(0.0, _cancelThreshold * 2);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.emergencySettings.enableDragToCancel) return;

    if (_dragDistance >= _cancelThreshold) {
      _emergencyService.cancelEmergencyCall();
    } else {
      setState(() {
        _dragDistance = 0;
      });
    }

    _isDragging = false;
    _dragController.reverse();
  }

  String _getStatusText() {
    switch (_currentState) {
      case EmergencyCallState.initializing:
        return 'Initializing emergency call...';
      case EmergencyCallState.calling:
        if (_currentContact != null) {
          return 'Calling ${_currentContact!.name}...';
        }
        return 'Calling emergency contact...';
      case EmergencyCallState.callingEmergencyServices:
        return 'Calling ${widget.emergencySettings.emergencyServiceNumber}...';
      case EmergencyCallState.completed:
        return 'Emergency call completed';
      case EmergencyCallState.cancelled:
        return 'Emergency call cancelled';
      case EmergencyCallState.error:
        return 'Error occurred';
      default:
        return 'Calling emergency...';
    }
  }

  String _getSubtitleText() {
    if (_currentState == EmergencyCallState.calling &&
        _currentContact != null) {
      return 'Calling ${_currentContact!.name} (${_currentContact!.phoneNumber})\n'
          'If no response, next contact will be called automatically.';
    }

    if (_currentState == EmergencyCallState.callingEmergencyServices) {
      return 'All emergency contacts exhausted.\n'
          'Calling emergency services now.';
    }

    return 'Please stand by, we are currently requesting\n'
        'for help. Your emergency contacts and nearby\n'
        'rescue services will see your call for help.';
  }

  Color _getStepColor() {
    switch (_currentState) {
      case EmergencyCallState.initializing:
        return Color(0xFFFF9F40); // Orange
      case EmergencyCallState.calling:
        return Color(0xFFFF6B6B); // Red-orange
      case EmergencyCallState.callingEmergencyServices:
        return Color(0xFFFF4444); // Bright red
      case EmergencyCallState.completed:
        return Color(0xFF4CAF50); // Green
      case EmergencyCallState.cancelled:
        return Color(0xFF757575); // Gray
      case EmergencyCallState.error:
        return Color(0xFFFF5722); // Deep orange
      default:
        return Color(0xFFFF6B6B);
    }
  }

  Widget _buildMainCircle() {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: Offset(0, _dragDistance),
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
                            color: _getStepColor().withOpacity(0.3 - (i * 0.1)),
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
                    child: Center(child: _buildCircleContent()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCircleContent() {
    if (_countdown > 0) {
      return Text(
        '$_countdown',
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (_currentState == EmergencyCallState.calling) {
      return Icon(Icons.phone, color: Colors.white, size: 48);
    }

    if (_currentState == EmergencyCallState.callingEmergencyServices) {
      return Icon(Icons.local_hospital, color: Colors.white, size: 48);
    }

    if (_currentState == EmergencyCallState.completed) {
      return Icon(Icons.check, color: Colors.white, size: 48);
    }

    if (_currentState == EmergencyCallState.cancelled) {
      return Icon(Icons.close, color: Colors.white, size: 48);
    }

    return Icon(Icons.emergency, color: Colors.white, size: 48);
  }

  Widget _buildDragToCancel() {
    if (!widget.emergencySettings.enableDragToCancel) return SizedBox.shrink();

    double opacity = (_dragDistance / _cancelThreshold).clamp(0.0, 1.0);
    bool willCancel = _dragDistance >= _cancelThreshold;

    return AnimatedOpacity(
      opacity: _isDragging ? 1.0 : 0.3,
      duration: Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:
              willCancel
                  ? Colors.red.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              willCancel ? Icons.cancel : Icons.arrow_downward,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              willCancel ? 'Release to Cancel' : 'Drag down to cancel',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_currentState == EmergencyCallState.calling) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _emergencyService.markContactResponded(),
            icon: Icon(Icons.check),
            label: Text('Contact Responded'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _emergencyService.cancelEmergencyCall(),
            icon: Icon(Icons.close),
            label: Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return SizedBox.shrink();
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
                _getStatusText(),
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),

              // Subtitle
              Text(
                _getSubtitleText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMainCircle(),
                      SizedBox(height: 40),
                      _buildDragToCancel(),
                    ],
                  ),
                ),
              ),

              _buildActionButtons(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dragController.dispose();
    _stateSubscription.cancel();
    _contactSubscription.cancel();
    _countdownSubscription.cancel();
    super.dispose();
  }
}
