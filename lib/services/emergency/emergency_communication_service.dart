// services/emergency/emergency_communication_service.dart (Enhanced with Emergency Service Sound)
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

  // EMERGENCY SERVICE SOUND - New Addition
  Future<void> startEmergencyServiceSound() async {
    if (_isPlayingEmergencyServiceSound) {
      print('Emergency service sound already playing');
      return;
    }

    _isPlayingEmergencyServiceSound = true;
    print('🚨📞 Starting EMERGENCY SERVICE sound');

    try {
      // Stop any existing emergency sounds first
      stopEmergencySound();

      // Method 1: Try custom emergency service sound
      await _playCustomEmergencyServiceSound();

      // Method 2: Fallback to distinct system alert pattern
      if (!await _isAudioPlaying()) {
        await _playEmergencyServiceAlertPattern();
      }

      // Enhanced haptic for emergency service
      await _performEmergencyServiceHaptics();
    } catch (e) {
      print('Error starting emergency service sound: $e');
      await _playBasicEmergencyServiceSound();
    }
  }

  Future<void> _playCustomEmergencyServiceSound() async {
    try {
      // Play a different sound for emergency services (if available)
      await _audioPlayer.setSource(
        AssetSource('sounds/emergency_service_alert.mp3'),
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();

      print('✅ Custom emergency service sound started');

      // Stop after 20 seconds for emergency service
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

      // Different pattern for emergency service - more urgent double beeps
      _soundTimer = Timer.periodic(Duration(milliseconds: 300), (timer) async {
        if (!_isPlayingEmergencyServiceSound) {
          timer.cancel();
          return;
        }

        try {
          // Double beep pattern for emergency service
          await SystemSound.play(SystemSoundType.alert);
          await Future.delayed(Duration(milliseconds: 100));
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.heavyImpact();
        } catch (e) {
          print('Error in emergency service beep: $e');
        }
      });

      // Stop after 20 seconds
      Timer(Duration(seconds: 20), () {
        stopEmergencyServiceSound();
      });
    } catch (e) {
      print('Error creating synthetic emergency service sound: $e');
    }
  }

  Future<void> _playEmergencyServiceAlertPattern() async {
    try {
      // Distinct alert pattern for emergency service
      for (int i = 0; i < 8; i++) {
        if (!_isPlayingEmergencyServiceSound) break;

        // Triple alert pattern
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
      // More intense haptic pattern for emergency service
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
      // Fallback: rapid system alerts for emergency service
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

  // EXISTING EMERGENCY SOUND METHODS (Modified to work with new service sound)
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

  // SMS AND CALLING METHODS (Simplified for brevity)
  Future<bool> sendDirectSMS(
    String phoneNumber,
    String message,
    bool smsPermissionGranted,
  ) async {
    if (!smsPermissionGranted) return false;

    bool success = await _sendViaTelephony(phoneNumber, message);
    if (success) return true;

    success = await _sendViaUrlLauncher(phoneNumber, message);
    return success;
  }

  Future<bool> _sendViaTelephony(String phoneNumber, String message) async {
    try {
      final bool? canSendSms = await _telephony.isSmsCapable;
      if (canSendSms != true) return false;

      final Completer<bool> completer = Completer<bool>();
      bool statusReceived = false;

      await _telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) {
          if (!statusReceived) {
            statusReceived = true;
            if (!completer.isCompleted) {
              completer.complete(status == SendStatus.SENT);
            }
          }
        },
      );

      return await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () => true,
      );
    } catch (e) {
      print('Error sending SMS via telephony: $e');
      return false;
    }
  }

  Future<bool> _sendViaUrlLauncher(String phoneNumber, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending SMS via URL launcher: $e');
      return false;
    }
  }

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

  Future<Map<String, bool>> sendLocationToAllContacts(
    List<EmergencyContact> contacts,
    String locationMessage,
    bool smsPermissionGranted,
  ) async {
    Map<String, bool> results = {};

    print('Sending location to ${contacts.length} contacts');

    for (var contact in contacts) {
      if (contact.sendLocationSMS) {
        print(
          'Sending location SMS to ${contact.name} (${contact.phoneNumber})',
        );

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

        // Small delay between messages to avoid overwhelming the system
        await Future.delayed(Duration(milliseconds: 1000));
      } else {
        print(
          'Skipping location SMS for ${contact.name} (disabled in settings)',
        );
      }
    }

    return results;
  }

  Future<Map<String, bool>> sendEmergencyMessages(
    List<EmergencyContact> contacts,
    String emergencyMessage,
    bool smsPermissionGranted,
  ) async {
    Map<String, bool> results = {};
    final sortedContacts = List<EmergencyContact>.from(contacts)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (var contact in sortedContacts) {
      bool success = await sendDirectSMS(
        contact.phoneNumber,
        emergencyMessage,
        smsPermissionGranted,
      );
      results[contact.phoneNumber] = success;
      await Future.delayed(Duration(milliseconds: 500));
    }

    return results;
  }

  Future<bool> checkAndRequestSmsPermission() async {
    try {
      var status = await Permission.sms.status;
      if (status.isGranted) return true;
      if (status.isDenied) {
        status = await Permission.sms.request();
        return status.isGranted;
      }
      return false;
    } catch (e) {
      print('Error checking SMS permission: $e');
      return false;
    }
  }

  void dispose() {
    stopEmergencySound();
    stopEmergencyServiceSound();
    _audioPlayer.dispose();
  }
}
