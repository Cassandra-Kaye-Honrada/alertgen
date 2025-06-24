// services/emergency/emergency_service.dart (Fixed Contact Progression Issue)

import 'package:phone_state/phone_state.dart'; // Add this dependency
import 'dart:io' show Platform;

import 'dart:async';
import 'package:allergen/screens/models/emergency_call_state.dart';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:allergen/screens/models/emergency_settings.dart';
import 'package:allergen/services/emergency/emergency_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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

  // Enhanced call management - FIXED
  Timer? _callTimeoutTimer;
  Timer? _postCallDelayTimer;
  bool _isCurrentlyInCall = false;
  bool _shouldContinueEmergencySequence = true;
  bool _isWaitingForCallTimeout = false;
  int _currentContactIndex = 0;

  // NEW: Add unique sequence ID to prevent stale timeouts
  int _currentSequenceId = 0;
  bool _isSequenceActive = false;

  // FIXED: Add call completion tracking
  Completer<void>? _callCompletionCompleter;

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

  // NEW: Call state monitoring
  StreamSubscription<PhoneState>? _phoneStateSubscription;
  bool _callStateMonitoringEnabled = false;
  String? _currentCallNumber;
  DateTime? _callStartTime;

  Future<bool> _makeCallAndWaitForTimeout(
    EmergencyContact contact,
    EmergencySettings settings,
    int sequenceId,
  ) async {
    print(
      '📞 [Seq #$sequenceId] Making call to ${contact.name} (${contact.phoneNumber})',
    );

    _isCurrentlyInCall = true;
    _isWaitingForCallTimeout = true;
    _currentCallNumber = contact.phoneNumber;
    _callStartTime = DateTime.now();

    // FIXED: Create new completer for this call
    _callCompletionCompleter = Completer<void>();

    // Start monitoring call state
    await _startCallStateMonitoring(contact.phoneNumber, sequenceId);

    // Make the call
    await _communicationService.makeDirectCall(
      contact.phoneNumber,
      _permissionService.phonePermissionGranted,
    );

    print(
      '📞 [Seq #$sequenceId] Call initiated, monitoring call state with 15-second max timeout',
    );

    bool timedOut = false;
    bool callEndedNaturally = false;

    // FIXED: Cancel any existing timer before creating new one
    _callTimeoutTimer?.cancel();

    // Set maximum timeout of 15 seconds
    _callTimeoutTimer = Timer(Duration(seconds: 15), () {
      print(
        '⏰ [Seq #$sequenceId] 15-second MAX timeout reached for ${contact.name}',
      );
      if (sequenceId == _currentSequenceId &&
          _isSequenceActive &&
          _isWaitingForCallTimeout) {
        timedOut = true;
        _handleCallTimeout(sequenceId, isMaxTimeout: true);
      }
    });

    // FIXED: Wait for either timeout, call end, or manual cancellation
    try {
      await _callCompletionCompleter!.future;
    } catch (e) {
      print('Call completion error: $e');
    }

    // Stop call state monitoring
    await _stopCallStateMonitoring();

    // Cleanup
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;
    _callCompletionCompleter = null;
    _currentCallNumber = null;
    _callStartTime = null;

    print(
      '📞 [Seq #$sequenceId] Call to ${contact.name} completed. Timed out: $timedOut, Natural end: $callEndedNaturally',
    );

    // Return true only if the call timed out (not if it ended naturally or was cancelled)
    return timedOut;
  }

  // NEW: Start call state monitoring
  Future<void> _startCallStateMonitoring(
    String phoneNumber,
    int sequenceId,
  ) async {
    if (!Platform.isAndroid) {
      print('Call state monitoring only available on Android');
      return;
    }

    try {
      // Stop any existing monitoring
      await _stopCallStateMonitoring();

      _callStateMonitoringEnabled = true;

      // Monitor phone state changes
      _phoneStateSubscription = PhoneState.stream.listen((PhoneState state) {
        _handlePhoneStateChange(state, phoneNumber, sequenceId);
      });

      print(
        '📱 [Seq #$sequenceId] Started call state monitoring for $phoneNumber',
      );
    } catch (e) {
      print('Error starting call state monitoring: $e');
      // Fallback to timer-only approach
    }
  }

  // NEW: Handle phone state changes
  void _handlePhoneStateChange(
    PhoneState state,
    String phoneNumber,
    int sequenceId,
  ) {
    if (sequenceId != _currentSequenceId ||
        !_isSequenceActive ||
        !_callStateMonitoringEnabled) {
      return;
    }

    print(
      '📱 [Seq #$sequenceId] Phone state changed: ${state.status} - ${state.number}',
    );

    switch (state.status) {
      case PhoneStateStatus.CALL_STARTED:
        if (_isCurrentCallForContact(state.number, phoneNumber)) {
          print(
            '📞 [Seq #$sequenceId] Call STARTED detected for ${phoneNumber}',
          );
          // Call has started, we're good
        }
        break;

      case PhoneStateStatus.CALL_ENDED:
        if (_isCurrentCallForContact(state.number, phoneNumber)) {
          print('📞 [Seq #$sequenceId] Call ENDED detected for ${phoneNumber}');
          _handleCallEndedNaturally(sequenceId);
        }
        break;

      case PhoneStateStatus.CALL_INCOMING:
        // Handle incoming calls - we don't need to do anything special here
        // as we're only monitoring outgoing emergency calls
        print('📞 [Seq #$sequenceId] Incoming call detected: ${state.number}');
        break;

      case PhoneStateStatus.NOTHING:
        // Call has ended or was never started
        if (_isWaitingForCallTimeout && _callStartTime != null) {
          // If we've been waiting for more than 2 seconds and state is NOTHING,
          // the call likely ended or was rejected
          final elapsed = DateTime.now().difference(_callStartTime!);
          if (elapsed.inSeconds >= 2) {
            print(
              '📞 [Seq #$sequenceId] Call likely ended/rejected for ${phoneNumber} (state: NOTHING after ${elapsed.inSeconds}s)',
            );
            _handleCallEndedNaturally(sequenceId);
          }
        }
        break;
    }
  }

  // NEW: Check if the phone state change is for our current call
  bool _isCurrentCallForContact(String? stateNumber, String targetNumber) {
    if (stateNumber == null || targetNumber.isEmpty) return false;

    // Clean both numbers for comparison
    String cleanStateNumber = _cleanPhoneNumber(stateNumber);
    String cleanTargetNumber = _cleanPhoneNumber(targetNumber);

    // Check if they match (exact or partial match for last 7+ digits)
    return cleanStateNumber == cleanTargetNumber ||
        (cleanStateNumber.length >= 7 &&
            cleanTargetNumber.length >= 7 &&
            cleanStateNumber.substring(cleanStateNumber.length - 7) ==
                cleanTargetNumber.substring(cleanTargetNumber.length - 7));
  }

  // NEW: Clean phone number for comparison
  String _cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  // NEW: Handle call ended naturally (not timeout)
  void _handleCallEndedNaturally(int sequenceId) {
    if (sequenceId != _currentSequenceId ||
        !_isSequenceActive ||
        !_isWaitingForCallTimeout) {
      return;
    }

    print(
      '📞 [Seq #$sequenceId] Call ended naturally - NOT continuing to next contact',
    );

    // Mark that we should not continue the sequence
    _shouldContinueEmergencySequence = false;

    // Complete the call completer to signal natural end
    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      _callCompletionCompleter!.complete();
    }
  }

  // NEW: Stop call state monitoring
  Future<void> _stopCallStateMonitoring() async {
    _callStateMonitoringEnabled = false;
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
  }

  //
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

      bool smsGranted =
          await _communicationService.checkAndRequestSmsPermission();
      if (!smsGranted) {
        print('❌ SMS permission not granted');
        return {};
      }

      if (includeLocation && _permissionService.locationPermissionGranted) {
        await _locationService.getCurrentLocationAndAddress();
      }

      String message =
          customMessage ?? _createEmergencyMessage(includeLocation);

      Map<String, bool> results = await _communicationService
          .sendEmergencyMessages(_emergencyContacts, message, smsGranted);

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

  // 🆕 FIXED EMERGENCY CALLING FUNCTIONALITY
  Future<void> startEmergencyCall({
    List<EmergencyContact>? contacts,
    EmergencySettings? settings,
  }) async {
    if (_stateManager.currentState != EmergencyCallState.idle) {
      print('Emergency call already in progress');
      return;
    }

    try {
      // FIXED: Reset all state properly
      _cleanupCurrentSequence();

      _shouldContinueEmergencySequence = true;
      _isCurrentlyInCall = false;
      _isWaitingForCallTimeout = false;
      _currentContactIndex = 0;
      _currentSequenceId++; // NEW: Increment sequence ID
      _isSequenceActive = true; // NEW: Mark sequence as active

      _stateManager.resetState();

      final contactsToUse = contacts ?? _emergencyContacts;
      final settingsToUse = settings ?? _emergencySettings;

      if (contactsToUse.isEmpty) {
        print('No emergency contacts available');
        _stateManager.updateState(EmergencyCallState.error);
        _isSequenceActive = false;
        return;
      }

      final sortedContacts = List<EmergencyContact>.from(contactsToUse)
        ..sort((a, b) => a.priority.compareTo(b.priority));
      _stateManager.setRemainingContacts(sortedContacts);

      _stateManager.updateState(EmergencyCallState.initializing);

      print(
        '🚨 Starting emergency sequence #$_currentSequenceId with ${sortedContacts.length} contacts',
      );

      // Get location if permission granted
      if (_permissionService.locationPermissionGranted) {
        await _locationService.getCurrentLocationAndAddress();
      }

      // Send location to all contacts if configured
      if (settingsToUse.autoSendLocationToAll &&
          _locationService.currentPosition != null) {
        Map<String, bool> results = await _communicationService
            .sendLocationToAllContacts(
              sortedContacts,
              _locationService.createLocationMessage(),
              _permissionService.smsPermissionGranted,
            );

        int successCount = results.values.where((success) => success).length;
        print(
          'Location messages sent: $successCount/${results.length} successful',
        );
      }

      await _startCallingSequence(settingsToUse);
    } catch (e) {
      print('Emergency service error: $e');
      _stateManager.updateState(EmergencyCallState.error);
      _isSequenceActive = false;
    }
  }

  // NEW: Clean up current sequence
  void _cleanupCurrentSequence() {
    _callTimeoutTimer?.cancel();
    _postCallDelayTimer?.cancel();
    _callTimeoutTimer = null;
    _postCallDelayTimer = null;
    _callCompletionCompleter?.complete();
    _callCompletionCompleter = null;
    _communicationService.stopEmergencySound();
    _communicationService.stopEmergencyServiceSound();
    _stateManager.cancelTimer();

    // NEW: Stop call state monitoring
    _stopCallStateMonitoring();
  }

  // 🆕 FIXED: Enhanced calling sequence with proper contact progression
  Future<void> _startCallingSequence(EmergencySettings settings) async {
    final sortedContacts = List<EmergencyContact>.from(_emergencyContacts)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final sequenceId = _currentSequenceId; // Capture current sequence ID

    print(
      '🚨 [Seq #$sequenceId] Starting calling sequence with ${sortedContacts.length} contacts',
    );

    // FIXED: Process each contact sequentially and wait for completion
    for (
      int contactIndex = 0;
      contactIndex < sortedContacts.length;
      contactIndex++
    ) {
      // Check if sequence is still valid
      if (!_shouldContinueEmergencySequence ||
          !_isSequenceActive ||
          sequenceId != _currentSequenceId) {
        print(
          '🛑 [Seq #$sequenceId] Sequence stopped or cancelled at contact $contactIndex',
        );
        break;
      }

      _currentContactIndex = contactIndex;
      final currentContact = sortedContacts[contactIndex];
      _stateManager.setCurrentContact(currentContact);
      _stateManager.updateState(EmergencyCallState.calling);

      print(
        '🚨 [Seq #$sequenceId] Starting call sequence for: ${currentContact.name} (${contactIndex + 1}/${sortedContacts.length})',
      );

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

      // Start 5-second countdown
      await _startCountdown(5, sequenceId);

      // Check if sequence is still valid after countdown
      if (!_shouldContinueEmergencySequence ||
          !_isSequenceActive ||
          sequenceId != _currentSequenceId) {
        print('🛑 [Seq #$sequenceId] Sequence invalidated after countdown');
        break;
      }

      // Stop the emergency sound before making the call
      _communicationService.stopEmergencySound();

      // FIXED: Make the call and properly wait for timeout completion
      bool callCompleted = await _makeCallAndWaitForTimeout(
        currentContact,
        settings,
        sequenceId,
      );

      // Check if sequence is still valid after call
      if (!_shouldContinueEmergencySequence ||
          !_isSequenceActive ||
          sequenceId != _currentSequenceId) {
        print('🛑 [Seq #$sequenceId] Sequence invalidated after call');
        break;
      }

      // FIXED: Only continue if the call actually timed out (not manually ended)
      if (!callCompleted) {
        print('🛑 [Seq #$sequenceId] Call sequence ended by user action');
        break;
      }

      print(
        '⏰ [Seq #$sequenceId] Call to ${currentContact.name} timed out, moving to next contact',
      );

      // Small delay before next contact
      if (contactIndex < sortedContacts.length - 1) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    // FIXED: All contacts exhausted, call emergency services
    if (_shouldContinueEmergencySequence &&
        _isSequenceActive &&
        sequenceId == _currentSequenceId) {
      print(
        '🚨 [Seq #$sequenceId] All contacts exhausted, proceeding to emergency services',
      );
      await _callEmergencyServices(settings, sequenceId);
    } else {
      print(
        '🛑 [Seq #$sequenceId] Sequence ended without calling emergency services',
      );
      _isSequenceActive = false;
    }
  }

  // 🆕 FIXED: Handle call timeout with sequence validation
  void _handleCallTimeout(int sequenceId, {bool isMaxTimeout = false}) {
    // FIXED: Only handle timeout if it's for the current sequence
    if (sequenceId != _currentSequenceId || !_isSequenceActive) {
      print(
        '🛑 [Seq #$sequenceId] Ignoring stale timeout - current sequence is #$_currentSequenceId',
      );
      return;
    }

    if (_isWaitingForCallTimeout && _shouldContinueEmergencySequence) {
      if (isMaxTimeout) {
        print(
          '⏰ [Seq #$sequenceId] Maximum timeout reached - will continue to next contact',
        );
      } else {
        print(
          '⏰ [Seq #$sequenceId] Handling call timeout - will continue to next contact',
        );
      }

      // Complete the call completer to signal timeout completion
      if (_callCompletionCompleter != null &&
          !_callCompletionCompleter!.isCompleted) {
        _callCompletionCompleter!.complete();
      }
    }
  }

  // 🆕 FIXED: Improved countdown with sequence validation
  Future<void> _startCountdown(int countdownSeconds, int sequenceId) async {
    print(
      '🕐 [Seq #$sequenceId] Starting ${countdownSeconds}-second countdown',
    );

    for (int i = countdownSeconds; i > 0; i--) {
      // FIXED: Check sequence validity
      if (!_shouldContinueEmergencySequence ||
          _stateManager.currentState == EmergencyCallState.cancelled ||
          sequenceId != _currentSequenceId ||
          !_isSequenceActive) {
        print('🛑 [Seq #$sequenceId] Countdown cancelled');
        break;
      }

      _stateManager.addCountdown(i);
      print('🕐 [Seq #$sequenceId] Countdown: $i');

      // Play different sounds based on countdown
      if (i <= 3) {
        await _communicationService.playFinalCountdownSound();
      } else {
        await _communicationService.playCountdownBeep();
      }

      await Future.delayed(Duration(seconds: 1));
    }

    if (_shouldContinueEmergencySequence &&
        _stateManager.currentState != EmergencyCallState.cancelled &&
        sequenceId == _currentSequenceId &&
        _isSequenceActive) {
      _stateManager.addCountdown(0);
      print('🕐 [Seq #$sequenceId] Countdown complete');
    }
  }

  // 🆕 FIXED: Emergency services calling with sequence validation
  Future<void> _callEmergencyServices(
    EmergencySettings settings,
    int sequenceId,
  ) async {
    if (!_shouldContinueEmergencySequence ||
        sequenceId != _currentSequenceId ||
        !_isSequenceActive) {
      print(
        '🏁 [Seq #$sequenceId] Emergency sequence completed - not calling emergency services',
      );
      _stateManager.updateState(EmergencyCallState.completed);
      _isSequenceActive = false;
      return;
    }

    _stateManager.setCurrentContact(null);
    _stateManager.updateState(EmergencyCallState.callingEmergencyServices);

    print(
      '🚨📞 [Seq #$sequenceId] All contacts exhausted - calling emergency services',
    );

    // Start special emergency service sound
    if (settings.playAlertSound) {
      await _communicationService.startEmergencyServiceSound();
    }

    // 5-second countdown before calling emergency services
    print(
      '🚨📞 [Seq #$sequenceId] Starting 5-second countdown before calling emergency services',
    );

    for (int i = 5; i > 0; i--) {
      if (_stateManager.currentState !=
              EmergencyCallState.callingEmergencyServices ||
          !_shouldContinueEmergencySequence ||
          sequenceId != _currentSequenceId ||
          !_isSequenceActive) {
        _communicationService.stopEmergencyServiceSound();
        return;
      }

      _stateManager.addCountdown(i);
      print('🚨📞 [Seq #$sequenceId] Emergency services countdown: $i');

      if (i <= 3) {
        await _communicationService.playFinalCountdownSound();
      } else {
        await _communicationService.playCountdownBeep();
      }

      await Future.delayed(Duration(seconds: 1));
    }

    if (_stateManager.currentState ==
            EmergencyCallState.callingEmergencyServices &&
        _shouldContinueEmergencySequence &&
        sequenceId == _currentSequenceId &&
        _isSequenceActive) {
      _stateManager.addCountdown(0);

      // Stop the emergency service sound before making the call
      _communicationService.stopEmergencyServiceSound();

      print(
        '🚨📞 [Seq #$sequenceId] Calling emergency services: ${settings.emergencyServiceNumber}',
      );

      // Make the call to emergency services
      await _communicationService.makeDirectCall(
        settings.emergencyServiceNumber,
        _permissionService.phonePermissionGranted,
      );

      // Complete after 5 seconds
      Timer(Duration(seconds: 30), () {
        // Give more time for emergency services
        if (_stateManager.currentState ==
                EmergencyCallState.callingEmergencyServices &&
            sequenceId == _currentSequenceId) {
          print('🏁 [Seq #$sequenceId] Emergency services call completed');
          _stateManager.updateState(EmergencyCallState.completed);
          _isSequenceActive = false;
        }
      });
    }
  }

  // 🆕 FIXED: Cancel emergency call
  void cancelEmergencyCall() {
    print('🛑 [Seq #$_currentSequenceId] Cancelling emergency call sequence');

    _shouldContinueEmergencySequence = false;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;
    _isSequenceActive = false; // NEW: Mark sequence as inactive

    // FIXED: Complete any pending call completion
    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      _callCompletionCompleter!.complete();
    }

    _cleanupCurrentSequence();
    _stateManager.updateState(EmergencyCallState.cancelled);

    // Reset after a short delay
    Timer(Duration(seconds: 2), () {
      _stateManager.resetState();
      _currentContactIndex = 0;
    });
  }

  // 🆕 FIXED: Mark contact responded
  void markContactResponded() {
    print(
      '✅ [Seq #$_currentSequenceId] Contact responded - ending emergency sequence',
    );

    _shouldContinueEmergencySequence = false;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;
    _isSequenceActive = false; // NEW: Mark sequence as inactive

    // FIXED: Complete any pending call completion
    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      _callCompletionCompleter!.complete();
    }

    _cleanupCurrentSequence();
    _stateManager.updateState(EmergencyCallState.completed);

    // Reset after a short delay
    Timer(Duration(seconds: 2), () {
      _stateManager.resetState();
      _currentContactIndex = 0;
    });
  }

  // 🆕 FIXED: Skip to next contact manually
  void skipToNextContact() {
    if (_isWaitingForCallTimeout &&
        _shouldContinueEmergencySequence &&
        _isSequenceActive) {
      print('⏭️ [Seq #$_currentSequenceId] Manually skipping to next contact');

      _callTimeoutTimer?.cancel();
      _isCurrentlyInCall = false;
      _isWaitingForCallTimeout = false;

      // FIXED: Complete the call completer to signal manual skip
      if (_callCompletionCompleter != null &&
          !_callCompletionCompleter!.isCompleted) {
        _callCompletionCompleter!.complete();
      }
    }
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
                Text(
                  'Emergency services require phone and SMS permissions to function properly.',
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _permissionService.phonePermissionGranted
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          _permissionService.phonePermissionGranted
                              ? Colors.green
                              : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Phone Permission'),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _permissionService.smsPermissionGranted
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          _permissionService.smsPermissionGranted
                              ? Colors.green
                              : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('SMS Permission'),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _permissionService.locationPermissionGranted
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _permissionService.locationPermissionGranted
                              ? Colors.green
                              : Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Location Permission (optional)'),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await requestPermissionsManually();
                },
                child: Text('Grant Permissions'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  void _showNoContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('No Emergency Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.contacts_outlined, size: 48, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'You need to add emergency contacts before using this feature.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showSettings(context);
                },
                child: Text('Add Contacts'),
              ),
            ],
          ),
    );
  }

  // Emergency widget integration
  Stream<bool> get isEmergencyActiveStream {
    return _stateManager.stateStream.map(
      (state) =>
          state != EmergencyCallState.idle &&
          state != EmergencyCallState.completed &&
          state != EmergencyCallState.cancelled,
    );
  }

  bool get isEmergencyActive {
    final state = _stateManager.currentState;
    return state != EmergencyCallState.idle &&
        state != EmergencyCallState.completed &&
        state != EmergencyCallState.cancelled;
  }

  // Testing and debugging methods
  void debugPrintState() {
    print('=== Emergency Service Debug State ===');
    print('Current State: ${_stateManager.currentState}');
    print('Is Initialized: $_isInitialized');
    print('Contacts Count: ${_emergencyContacts.length}');
    print('Current Contact Index: $_currentContactIndex');
    print('Is Currently In Call: $_isCurrentlyInCall');
    print('Is Waiting For Call Timeout: $_isWaitingForCallTimeout');
    print(
      'Should Continue Emergency Sequence: $_shouldContinueEmergencySequence',
    );
    print('Current Sequence ID: $_currentSequenceId');
    print('Is Sequence Active: $_isSequenceActive');
    print('SMS Permission: ${_permissionService.smsPermissionGranted}');
    print('Phone Permission: ${_permissionService.phonePermissionGranted}');
    print(
      'Location Permission: ${_permissionService.locationPermissionGranted}',
    );
    print('=====================================');
  }

  // Cleanup method
  void dispose() {
    print('Disposing EmergencyService');

    _shouldContinueEmergencySequence = false;
    _isSequenceActive = false;

    _cleanupCurrentSequence();
    _stopCallStateMonitoring();
    _authSubscription?.cancel();
    _stateManager.dispose();
    _locationService.dispose();
    _communicationService.dispose();

    _isInitialized = false;

    print('EmergencyService disposed');
  }

  // Health check method
  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'isInitialized': _isInitialized,
      'contactsCount': _emergencyContacts.length,
      'hasPermissions': {
        'sms': _permissionService.smsPermissionGranted,
        'phone': _permissionService.phonePermissionGranted,
        'location': _permissionService.locationPermissionGranted,
      },
      'currentState': _stateManager.currentState.toString(),
      'isActive': isEmergencyActive,
      'sequenceId': _currentSequenceId,
      'locationAvailable': _locationService.currentPosition != null,
    };
  }

  // Utility method to validate emergency setup
  Future<List<String>> validateEmergencySetup() async {
    List<String> issues = [];

    if (!_isInitialized) {
      issues.add('Emergency service not initialized');
    }

    if (_emergencyContacts.isEmpty) {
      issues.add('No emergency contacts configured');
    }

    if (!_permissionService.phonePermissionGranted) {
      issues.add('Phone permission not granted');
    }

    if (!_permissionService.smsPermissionGranted) {
      issues.add('SMS permission not granted');
    }

    // Check for duplicate contacts
    Set<String> phoneNumbers = {};
    for (var contact in _emergencyContacts) {
      if (phoneNumbers.contains(contact.phoneNumber)) {
        issues.add('Duplicate phone number found: ${contact.phoneNumber}');
      }
      phoneNumbers.add(contact.phoneNumber);
    }

    // Check for invalid phone numbers
    for (var contact in _emergencyContacts) {
      if (contact.phoneNumber.isEmpty) {
        issues.add('Empty phone number for contact: ${contact.name}');
      }
    }

    return issues;
  }

  // Method to get emergency summary for UI
  Map<String, dynamic> getEmergencySummary() {
    return {
      'totalContacts': _emergencyContacts.length,
      'priorityContacts':
          _emergencyContacts.where((c) => c.priority <= 2).length,
      'locationEnabledContacts':
          _emergencyContacts.where((c) => c.sendLocationSMS).length,
      'autoCallEmergencyServices': _emergencySettings.autoCallEmergencyServices,
      'emergencyServiceNumber': _emergencySettings.emergencyServiceNumber,
      'playAlertSound': _emergencySettings.playAlertSound,
      'autoSendLocationToAll': _emergencySettings.autoSendLocationToAll,
      'autoSendLocationToCurrentContact':
          _emergencySettings.autoSendLocationToCurrentContact,
    };
  }
}
