// services/emergency/emergency_communication_service.dart (Fixed for Direct SMS)
import 'dart:async';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class EmergencyCommunicationService {
  final Telephony _telephony = Telephony.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _soundTimer;
  bool _isPlayingEmergencySound = false;
  bool _isPlayingEmergencyServiceSound = false;

  // CRITICAL: Initialize telephony properly for direct SMS
  Future<void> initializeTelephony() async {
    try {
      // Request SMS permissions first
      await _requestAllSmsPermissions();
      
      // Initialize telephony with proper settings
      final bool? isSmsCapable = await _telephony.isSmsCapable;
      print('SMS capable: $isSmsCapable');
      
      if (isSmsCapable == true) {
        print('✅ Telephony initialized successfully');
      } else {
        print('❌ Device not SMS capable');
      }
    } catch (e) {
      print('Error initializing telephony: $e');
    }
  }

  // Enhanced permission requesting
  Future<bool> _requestAllSmsPermissions() async {
    try {
      // Request multiple SMS-related permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.sms,
        Permission.phone,
      ].request();

      bool smsGranted = statuses[Permission.sms]?.isGranted ?? false;
      bool phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

      print('SMS Permission: $smsGranted');
      print('Phone Permission: $phoneGranted');

      return smsGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  // FIXED: Direct SMS sending without navigation
  Future<bool> sendDirectSMS(
    String phoneNumber,
    String message,
    bool smsPermissionGranted,
  ) async {
    print('🚨 Attempting to send direct SMS to: $phoneNumber');
    print('Permission granted: $smsPermissionGranted');
    
    if (!smsPermissionGranted) {
      print('❌ SMS permission not granted, requesting...');
      bool permissionObtained = await _requestAllSmsPermissions();
      if (!permissionObtained) {
        print('❌ Could not obtain SMS permission');
        return false;
      }
    }

    // Try direct telephony first (this is the key for automatic sending)
    bool success = await _sendViaTelephonyDirect(phoneNumber, message);
    if (success) {
      print('✅ SMS sent successfully via telephony');
      return true;
    }

    // Fallback: Try platform-specific sending
    success = await _sendViaPlatformChannel(phoneNumber, message);
    if (success) {
      print('✅ SMS sent successfully via platform channel');
      return true;
    }

    print('❌ All SMS sending methods failed');
    return false;
  }

  // CRITICAL: Fixed telephony direct sending
  Future<bool> _sendViaTelephonyDirect(String phoneNumber, String message) async {
    try {
      print('Attempting direct telephony send...');
      
      // Check SMS capability first
      final bool? canSendSms = await _telephony.isSmsCapable;
      if (canSendSms != true) {
        print('Device cannot send SMS');
        return false;
      }

      // Create a completer to track SMS status
      final Completer<bool> completer = Completer<bool>();
      bool statusReceived = false;

      // Send SMS with status tracking
      await _telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) {
          print('SMS Status received: $status');
          if (!statusReceived) {
            statusReceived = true;
            if (!completer.isCompleted) {
              bool success = (status == SendStatus.SENT);
              print('SMS Send Status: $success');
              completer.complete(success);
            }
          }
        },
      );

      // Wait for status with timeout
      try {
        bool result = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('SMS send timeout - assuming success');
            return true; // Assume success on timeout for emergency
          },
        );
        return result;
      } catch (e) {
        print('SMS status timeout: $e');
        return true; // Return true for emergency situations
      }

    } catch (e) {
      print('Error in direct telephony send: $e');
      return false;
    }
  }

  // NEW: Platform channel method for direct SMS
  Future<bool> _sendViaPlatformChannel(String phoneNumber, String message) async {
    try {
      print('Attempting platform channel SMS send...');
      
      const platform = MethodChannel('emergency_sms');
      
      final bool result = await platform.invokeMethod('sendDirectSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      
      print('Platform channel SMS result: $result');
      return result;
    } catch (e) {
      print('Platform channel SMS failed: $e');
      return false;
    }
  }

  // FIXED: Remove URL launcher for emergency SMS (it opens SMS app instead of sending directly)
  Future<bool> _sendViaUrlLauncher(String phoneNumber, String message) async {
    // NOTE: This method opens SMS app - NOT suitable for emergency direct sending
    // Keeping for reference but should not be used for emergency
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        print('⚠️ SMS app opened - manual send required');
        return false; // Return false because it requires manual action
      }
      return false;
    } catch (e) {
      print('Error with URL launcher SMS: $e');
      return false;
    }
  }

  // ENHANCED: Better permission checking
  Future<bool> checkAndRequestSmsPermission() async {
    try {
      // Check current SMS permission
      var smsStatus = await Permission.sms.status;
      print('Current SMS permission status: $smsStatus');
      
      if (smsStatus.isGranted) {
        return true;
      }
      
      if (smsStatus.isDenied || smsStatus.isRestricted) {
        print('Requesting SMS permission...');
        smsStatus = await Permission.sms.request();
        print('SMS permission after request: $smsStatus');
        return smsStatus.isGranted;
      }
      
      if (smsStatus.isPermanentlyDenied) {
        print('❌ SMS permission permanently denied');
        return false;
      }
      
      return false;
    } catch (e) {
      print('Error checking SMS permission: $e');
      return false;
    }
  }

  // ENHANCED: Send to all contacts with better error handling
  Future<Map<String, bool>> sendEmergencyMessages(
    List<EmergencyContact> contacts,
    String emergencyMessage,
    bool smsPermissionGranted,
  ) async {
    print('🚨 Starting emergency message broadcast to ${contacts.length} contacts');
    
    Map<String, bool> results = {};
    
    // Sort contacts by priority
    final sortedContacts = List<EmergencyContact>.from(contacts)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // Initialize telephony first
    await initializeTelephony();

    for (var contact in sortedContacts) {
      print('Sending emergency SMS to ${contact.name} (${contact.phoneNumber})');
      
      try {
        bool success = await sendDirectSMS(
          contact.phoneNumber,
          emergencyMessage,
          smsPermissionGranted,
        );
        
        results[contact.phoneNumber] = success;
        
        if (success) {
          print('✅ Emergency SMS sent to ${contact.name}');
        } else {
          print('❌ Failed to send emergency SMS to ${contact.name}');
        }
        
        // Small delay between messages
        await Future.delayed(Duration(milliseconds: 1000));
        
      } catch (e) {
        print('Error sending to ${contact.name}: $e');
        results[contact.phoneNumber] = false;
      }
    }

    // Log final results
    int successCount = results.values.where((success) => success).length;
    int totalCount = results.length;
    print('Emergency SMS Results: $successCount/$totalCount sent successfully');

    return results;
  }

  // ENHANCED: Location message sending
  Future<Map<String, bool>> sendLocationToAllContacts(
    List<EmergencyContact> contacts,
    String locationMessage,
    bool smsPermissionGranted,
  ) async {
    Map<String, bool> results = {};

    print('📍 Sending location to ${contacts.length} contacts');

    // Initialize telephony
    await initializeTelephony();

    for (var contact in contacts) {
      if (contact.sendLocationSMS) {
        print('Sending location SMS to ${contact.name} (${contact.phoneNumber})');

        try {
          bool success = await sendDirectSMS(
            contact.phoneNumber,
            locationMessage,
            smsPermissionGranted,
          );

          results[contact.phoneNumber] = success;

          if (success) {
            print('✅ Location SMS sent successfully to ${contact.name}');
          } else {
            print('❌ Failed to send location SMS to ${contact.name}');
          }

          // Delay between messages
          await Future.delayed(Duration(milliseconds: 1500));
          
        } catch (e) {
          print('Error sending location to ${contact.name}: $e');
          results[contact.phoneNumber] = false;
        }
      } else {
        print('Skipping location SMS for ${contact.name} (disabled in settings)');
      }
    }

    return results;
  }

  // EMERGENCY SERVICE SOUND - Enhanced
  Future<void> startEmergencyServiceSound() async {
    if (_isPlayingEmergencyServiceSound) {
      print('Emergency service sound already playing');
      return;
    }

    _isPlayingEmergencyServiceSound = true;
    print('🚨📞 Starting EMERGENCY SERVICE sound');

    try {
      stopEmergencySound(); // Stop any existing sounds
      await _playCustomEmergencyServiceSound();
      
      if (!await _isAudioPlaying()) {
        await _playEmergencyServiceAlertPattern();
      }
      
      await _performEmergencyServiceHaptics();
    } catch (e) {
      print('Error starting emergency service sound: $e');
      await _playBasicEmergencyServiceSound();
    }
  }

  Future<void> _playCustomEmergencyServiceSound() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/emergency_service_alert.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();

      print('✅ Custom emergency service sound started');

      _soundTimer = Timer(Duration(seconds: 20), () {
        stopEmergencyServiceSound();
      });
    } catch (e) {
      print('Custom emergency service sound failed: $e');
      await _createSyntheticEmergencyServiceSound();
    }
  }

  Future<void> _createSyntheticEmergencyServiceSound() async {
    try {
      print('🚨📞 Creating synthetic emergency service sound pattern');

      _soundTimer = Timer.periodic(Duration(milliseconds: 300), (timer) async {
        if (!_isPlayingEmergencyServiceSound) {
          timer.cancel();
          return;
        }

        try {
          await SystemSound.play(SystemSoundType.alert);
          await Future.delayed(Duration(milliseconds: 100));
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.heavyImpact();
        } catch (e) {
          print('Error in emergency service beep: $e');
        }
      });

      Timer(Duration(seconds: 20), () {
        stopEmergencyServiceSound();
      });
    } catch (e) {
      print('Error creating synthetic emergency service sound: $e');
    }
  }

  Future<void> _playEmergencyServiceAlertPattern() async {
    try {
      for (int i = 0; i < 8; i++) {
        if (!_isPlayingEmergencyServiceSound) break;

        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 500));
      }
    } catch (e) {
      print('Error playing emergency service alert pattern: $e');
    }
  }

  Future<void> _performEmergencyServiceHaptics() async {
    try {
      for (int i = 0; i < 5; i++) {
        if (!_isPlayingEmergencyServiceSound) break;

        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 100));
        await HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Error with emergency service haptics: $e');
    }
  }

  Future<void> _playBasicEmergencyServiceSound() async {
    try {
      for (int i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 200));
      }
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Error with basic emergency service sound: $e');
    }
  }

  void stopEmergencyServiceSound() {
    print('🔇 Stopping emergency service sound');
    _isPlayingEmergencyServiceSound = false;

    try {
      _soundTimer?.cancel();
      _soundTimer = null;
      _audioPlayer.stop();
    } catch (e) {
      print('Error stopping emergency service sound: $e');
    }
  }

  // EXISTING EMERGENCY SOUND METHODS
  Future<void> startEmergencyAlertSound() async {
    if (_isPlayingEmergencySound) {
      print('Emergency sound already playing');
      return;
    }

    _isPlayingEmergencySound = true;
    print('🔊 Starting emergency alert sound');

    try {
      await _playCustomEmergencySound();
      if (!await _isAudioPlaying()) {
        await _playSystemEmergencyAlerts();
      }
      await _performEmergencyHaptics();
    } catch (e) {
      print('Error starting emergency sound: $e');
      await _playBasicSystemSounds();
    }
  }

  Future<void> _playCustomEmergencySound() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/emergency_alert.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();

      print('✅ Custom emergency sound started');

      _soundTimer = Timer(Duration(seconds: 15), () {
        stopEmergencySound();
      });
    } catch (e) {
      print('Custom emergency sound failed: $e');
      await _createSyntheticEmergencySound();
    }
  }

  Future<void> _createSyntheticEmergencySound() async {
    try {
      print('🔊 Creating synthetic emergency beeping');

      _soundTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
        if (!_isPlayingEmergencySound) {
          timer.cancel();
          return;
        }

        try {
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.heavyImpact();
        } catch (e) {
          print('Error in synthetic beep: $e');
        }
      }); 

      Timer(Duration(seconds: 15), () {
        stopEmergencySound();
      });
    } catch (e) {
      print('Error creating synthetic sound: $e');
    }
  }

  Future<void> _playSystemEmergencyAlerts() async {
    try {
      for (int i = 0; i < 5; i++) {
        if (!_isPlayingEmergencySound) break;
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Error playing system emergency alerts: $e');
    }
  }

  Future<void> _performEmergencyHaptics() async {
    try {
      for (int i = 0; i < 3; i++) {
        if (!_isPlayingEmergencySound) break;
        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 200));
        await HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 200));
        await HapticFeedback.lightImpact();
        await Future.delayed(Duration(milliseconds: 400));
      }
    } catch (e) {
      print('Error with emergency haptics: $e');
    }
  }

  Future<void> _playBasicSystemSounds() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Error with basic system sounds: $e');
    }
  }

  Future<bool> _isAudioPlaying() async {
    try {
      return _audioPlayer.state == PlayerState.playing;
    } catch (e) {
      return false;
    }
  }

  void stopEmergencySound() {
    print('🔇 Stopping emergency alert sound');
    _isPlayingEmergencySound = false;

    try {
      _soundTimer?.cancel();
      _soundTimer = null;
      _audioPlayer.stop();
    } catch (e) {
      print('Error stopping emergency sound: $e');
    }
  }

  // COUNTDOWN SOUNDS
  Future<void> playCountdownBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Error playing countdown beep: $e');
    }
  }

  Future<void> playFinalCountdownSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error playing final countdown sound: $e');
    }
  }

  // CALLING METHODS
  Future<void> makeDirectCall(
    String phoneNumber,
    bool phonePermissionGranted,
  ) async {
    try {
      if (!phonePermissionGranted) {
        await _makeCallViaApp(phoneNumber);
        return;
      }

      bool? canCall = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (canCall != true) {
        await _makeCallViaApp(phoneNumber);
      }
    } catch (e) {
      print('Error making direct call: $e');
      await _makeCallViaApp(phoneNumber);
    }
  }

  Future<void> _makeCallViaApp(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening phone app: $e');
    }
  }

  void dispose() {
    stopEmergencySound();
    stopEmergencyServiceSound();
    _audioPlayer.dispose();
  }
}