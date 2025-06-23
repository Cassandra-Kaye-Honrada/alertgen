// services/emergency/emergency_service.dart (Fixed Version)
import 'dart:async';
import 'package:allergen/screens/models/emergency_call_state.dart';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:allergen/screens/models/emergency_settings.dart';
import 'package:allergen/services/emergency/emergency_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../screens/emergency/emergency_screen.dart';
import '../../../screens/emergency/emergency_settings_screen.dart';
import '../../../widgets/emergency_widget.dart';
import 'emergency_permission_service.dart';
import 'emergency_location_service.dart';
import 'emergency_communication_service.dart';
import 'emergency_storage_service.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  // Service dependencies
  final EmergencyStateManager _stateManager = EmergencyStateManager();
  final EmergencyPermissionService _permissionService =
      EmergencyPermissionService();
  final EmergencyLocationService _locationService = EmergencyLocationService();
  final EmergencyCommunicationService _communicationService =
      EmergencyCommunicationService();
  final EmergencyStorageService _storageService = EmergencyStorageService();

  // Data
  List<EmergencyContact> _emergencyContacts = [];
  EmergencySettings _emergencySettings = EmergencySettings();
  bool _isInitialized = false;
  StreamSubscription<User?>? _authSubscription;

  // Getters - delegate to state manager where appropriate
  Stream<EmergencyCallState> get stateStream => _stateManager.stateStream;
  Stream<EmergencyContact?> get currentContactStream =>
      _stateManager.currentContactStream;
  Stream<int> get countdownStream => _stateManager.countdownStream;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  EmergencySettings get emergencySettings => _emergencySettings;
  bool get isInitialized => _isInitialized;
  bool get hasContacts => _emergencyContacts.isNotEmpty;
  EmergencyCallState get currentState => _stateManager.currentState;
  bool get smsPermissionGranted => _permissionService.smsPermissionGranted;
  bool get phonePermissionGranted => _permissionService.phonePermissionGranted;
  bool get locationPermissionGranted =>
      _permissionService.locationPermissionGranted;

  Future<void> initialize() async {
    if (_isInitialized) {
      await forceReload();
      return;
    }

    try {
      await _loadSettings();
      await _permissionService.requestAllPermissions();
      _listenToAuthChanges();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing EmergencyService: $e');
      rethrow;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _storageService.loadSettings();
      _emergencyContacts = data['contacts'] ?? [];
      _emergencySettings = data['settings'] ?? EmergencySettings();
    } catch (e) {
      print('Error loading settings: $e');
      // Initialize with defaults on error
      _emergencyContacts = [];
      _emergencySettings = EmergencySettings();
    }
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null) {
        _storageService.syncOnLogin().catchError((e) {
          print('Error syncing on login: $e');
        });
      }
    });
  }

  Future<bool> requestPermissionsManually() async {
    try {
      await _permissionService.requestAllPermissions();
      return _permissionService.allPermissionsGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> forceReload() async {
    await _loadSettings();
  }

  Future<void> saveSettings(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    try {
      _emergencyContacts = contacts;
      _emergencySettings = settings;
      await _storageService.saveSettings(contacts, settings);
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  Future<void> syncOnLogin() async {
    try {
      await _storageService.syncOnLogin();
      await forceReload();
    } catch (e) {
      print('Error syncing on login: $e');
    }
  }

  // Send emergency messages without UI
  Future<Map<String, bool>> sendEmergencyMessagesDirectly({
    String? customMessage,
    bool includeLocation = true,
  }) async {
    print('🚨 EMERGENCY: Sending direct emergency messages');

    try {
      await forceReload();

      if (_emergencyContacts.isEmpty) {
        print('❌ No emergency contacts available');
        return {};
      }

      // Check and request SMS permission
      bool smsGranted =
          await _communicationService.checkAndRequestSmsPermission();
      if (!smsGranted) {
        print('❌ SMS permission not granted');
        return {};
      }

      // Get location if needed
      if (includeLocation && _permissionService.locationPermissionGranted) {
        await _locationService.getCurrentLocationAndAddress();
      }

      // Create emergency message
      String message =
          customMessage ?? _createEmergencyMessage(includeLocation);

      // Send messages to all contacts
      Map<String, bool> results = await _communicationService
          .sendEmergencyMessages(_emergencyContacts, message, smsGranted);

      // Log results
      int successCount = results.values.where((success) => success).length;
      print(
        '🚨 Emergency messages sent: $successCount/${results.length} successful',
      );

      return results;
    } catch (e) {
      print('Error sending emergency messages: $e');
      return {};
    }
  }

  String _createEmergencyMessage(bool includeLocation) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    if (includeLocation && _locationService.currentPosition != null) {
      return _locationService.createLocationMessage();
    } else {
      return '🚨 EMERGENCY: I need help!\n\nPlease call me immediately!\n\n🕐 Time: $timeStr on $dateStr';
    }
  }

  // EMERGENCY CALLING FUNCTIONALITY
  Future<void> startEmergencyCall({
    List<EmergencyContact>? contacts,
    EmergencySettings? settings,
  }) async {
    if (_stateManager.currentState != EmergencyCallState.idle) {
      print('Emergency call already in progress');
      return;
    }

    try {
      _stateManager.resetState();

      final contactsToUse = contacts ?? _emergencyContacts;
      final settingsToUse = settings ?? _emergencySettings;

      if (contactsToUse.isEmpty) {
        print('No emergency contacts available');
        _stateManager.updateState(EmergencyCallState.error);
        return;
      }

      final remainingContacts = List<EmergencyContact>.from(contactsToUse)
        ..sort((a, b) => a.priority.compareTo(b.priority));
      _stateManager.setRemainingContacts(remainingContacts);

      _stateManager.updateState(EmergencyCallState.initializing);

      // Get location if permission granted
      if (_permissionService.locationPermissionGranted) {
        await _locationService.getCurrentLocationAndAddress();
      }

      // Send location to all contacts if configured
      if (settingsToUse.autoSendLocationToAll &&
          _locationService.currentPosition != null) {
        Map<String, bool> results = await _communicationService
            .sendLocationToAllContacts(
              remainingContacts,
              _locationService.createLocationMessage(),
              _permissionService.smsPermissionGranted,
            );

        int successCount = results.values.where((success) => success).length;
        print(
          'Location messages sent: $successCount/${results.length} successful',
        );
      }

      await _startCallingContacts(settingsToUse);
    } catch (e) {
      print('Emergency service error: $e');
      _stateManager.updateState(EmergencyCallState.error);
    }
  }

  Future<void> _startCallingContacts(EmergencySettings settings) async {
    if (_stateManager.remainingContacts.isEmpty) {
      await _callEmergencyServices(settings);
      return;
    }

    final remainingContacts = List<EmergencyContact>.from(
      _stateManager.remainingContacts,
    );
    final currentContact = remainingContacts.removeAt(0);
    _stateManager.setRemainingContacts(remainingContacts);
    _stateManager.setCurrentContact(currentContact);
    _stateManager.updateState(EmergencyCallState.calling);

    // Send location SMS first if needed
    if (settings.autoSendLocationToCurrentContact &&
        currentContact.sendLocationSMS &&
        _locationService.currentPosition != null) {
      bool success = await _communicationService.sendDirectSMS(
        currentContact.phoneNumber,
        _locationService.createLocationMessage(),
        _permissionService.smsPermissionGranted,
      );

      if (success) {
        print('✅ Location SMS sent to ${currentContact.name}');
      } else {
        print('❌ Failed to send location SMS to ${currentContact.name}');
      }
    }

    // Start emergency alert sound during countdown if enabled
    if (settings.playAlertSound) {
      await _communicationService.startEmergencyAlertSound();
    }

    // Start countdown
    await _startCountdown(settings.countdownDuration ?? 3);

    // Stop the emergency sound before making the call
    _communicationService.stopEmergencySound();

    // Make the call after countdown
    await _communicationService.makeDirectCall(
      currentContact.phoneNumber,
      _permissionService.phonePermissionGranted,
    );

    _startCallTimer(settings);
  }

  // Add this method to stop sounds when emergency is cancelled:
  void cancelEmergencyCall() {
    _communicationService
        .stopEmergencySound(); // Stop any playing emergency sounds
    _stateManager.cancelTimer();
    _stateManager.updateState(EmergencyCallState.cancelled);
    _stateManager.resetState();
  }

  // Add this method to stop sounds when contact responds:
  void markContactResponded() {
    _communicationService
        .stopEmergencySound(); // Stop any playing emergency sounds
    _stateManager.cancelTimer();
    _stateManager.updateState(EmergencyCallState.completed);
    _stateManager.resetState();
  }

  Future<void> _startCountdown(int countdownSeconds) async {
    for (int i = countdownSeconds; i > 0; i--) {
      if (_stateManager.currentState != EmergencyCallState.calling) break;

      _stateManager.addCountdown(i);

      // Play different sounds based on countdown
      if (i <= 3) {
        await _communicationService
            .playFinalCountdownSound(); // More urgent sound for final seconds
      } else {
        await _communicationService.playCountdownBeep(); // Regular beep
      }

      await Future.delayed(Duration(seconds: 1));
    }

    if (_stateManager.currentState == EmergencyCallState.calling) {
      _stateManager.addCountdown(0);
    }
  }

  void _startCallTimer(EmergencySettings settings) {
    final timer = Timer(Duration(seconds: settings.callTimeoutSeconds), () {
      _onCallTimeout(settings);
    });
    _stateManager.setCallTimer(timer);
  }

  Future<void> _onCallTimeout(EmergencySettings settings) async {
    if (_stateManager.currentState == EmergencyCallState.calling) {
      if (_stateManager.remainingContacts.isNotEmpty) {
        await _startCallingContacts(settings);
      } else {
        await _callEmergencyServices(settings);
      }
    }
  }

  Future<void> _callEmergencyServices(EmergencySettings settings) async {
    if (!settings.autoCallEmergencyServices) {
      _stateManager.updateState(EmergencyCallState.completed);
      return;
    }

    _stateManager.setCurrentContact(null);
    _stateManager.updateState(EmergencyCallState.callingEmergencyServices);

    await _communicationService.makeDirectCall(
      settings.emergencyServiceNumber,
      _permissionService.phonePermissionGranted,
    );

    Timer(Duration(seconds: 5), () {
      if (_stateManager.currentState ==
          EmergencyCallState.callingEmergencyServices) {
        _stateManager.updateState(EmergencyCallState.completed);
      }
    });
  }

  String getCurrentLocationInfo() {
    return _locationService.getCurrentLocationInfo();
  }


  // UI INTEGRATION METHODS
  Future<void> startEmergencyCallFromUI(BuildContext context) async {
    try {
      await forceReload();

      if (_emergencyContacts.isEmpty) {
        _showNoContactsDialog(context);
        return;
      }

      if (!_permissionService.smsPermissionGranted ||
          !_permissionService.phonePermissionGranted) {
        bool granted = await _showPermissionDialog(context);
        if (!granted) return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => EmergencyScreen(
                emergencyContacts: _emergencyContacts,
                emergencySettings: _emergencySettings,
              ),
        ),
      );

      _stateManager.resetState();
    } catch (e) {
      print('Error starting emergency call from UI: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  // Send emergency messages from UI
  Future<void> sendEmergencyMessagesFromUI(BuildContext context) async {
    try {
      await forceReload();

      if (_emergencyContacts.isEmpty) {
        _showNoContactsDialog(context);
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending emergency messages...'),
                ],
              ),
            ),
      );

      Map<String, bool> results = await sendEmergencyMessagesDirectly();

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Show results dialog
      _showResultsDialog(context, results);
    } catch (e) {
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      _showErrorDialog(context, e.toString());
    }
  }

  void _showResultsDialog(BuildContext context, Map<String, bool> results) {
    int successCount = results.values.where((success) => success).length;
    int totalCount = results.length;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Emergency Messages Sent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Successfully sent: $successCount/$totalCount'),
                SizedBox(height: 12),
                ...results.entries.map((entry) {
                  String phoneNumber = entry.key;
                  bool success = entry.value;

                  // Find contact name
                  String contactName =
                      _emergencyContacts
                          .firstWhere(
                            (contact) => contact.phoneNumber == phoneNumber,
                            orElse:
                                () => EmergencyContact(
                                  id: '',
                                  name: phoneNumber,
                                  phoneNumber: phoneNumber,
                                  priority: 0,
                                  sendLocationSMS: false,
                                ),
                          )
                          .name;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(contactName)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Error'),
            content: Text('An error occurred: $error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> showSettings(BuildContext context) async {
    try {
      await forceReload();

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (context) => EmergencySettingsScreen(
                emergencyContacts: _emergencyContacts,
                emergencySettings: _emergencySettings,
                onSave: saveSettings,
                emergencyService: this,
              ),
        ),
      );

      if (result == true) {
        await forceReload();
      }
    } catch (e) {
      print('Error showing settings: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  Widget buildEmergencyWidget(
    BuildContext context, {
    bool showSettings = true,
    bool showStatus = true,
  }) {
    return EmergencyWidget(
      emergencyService: this,
      showSettings: showSettings,
      showStatus: showStatus,
    );
  }

  Future<bool> _showPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Permissions Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency features require the following permissions:'),
                SizedBox(height: 12),
                if (!_permissionService.smsPermissionGranted)
                  Row(
                    children: [
                      Icon(Icons.message, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('SMS - to send location messages'),
                    ],
                  ),
                if (!_permissionService.phonePermissionGranted)
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Phone - to make emergency calls'),
                    ],
                  ),
                if (!_permissionService.locationPermissionGranted)
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Location - to share your location'),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await requestPermissionsManually();
                },
                child: Text('Grant Permissions'),
              ),
            ],
          ),
    );
    return result == true;
  }

  void _showNoContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('No Emergency Contacts'),
            content: Text(
              'Please add emergency contacts before using the emergency feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showSettings(context);
                },
                child: Text('Add Contacts'),
              ),
            ],
          ),
    );
  }

  void dispose() {
    _authSubscription?.cancel();
    _stateManager.dispose();
    _communicationService.dispose();
    _locationService.dispose();
    _storageService.dispose();
    _permissionService.dispose();
  }
}
