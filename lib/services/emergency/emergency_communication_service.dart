// services/emergency/emergency_communication_service.dart (Enhanced Version)
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

  Future<bool> sendDirectSMS(
    String phoneNumber,
    String message,
    bool smsPermissionGranted,
  ) async {
    print('Attempting to send SMS to $phoneNumber');
    print('Message: $message');

    if (!smsPermissionGranted) {
      print('SMS permission not granted, cannot send direct SMS');
      return false;
    }

    // Method 1: Try with telephony package (primary method)
    bool success = await _sendViaTelephony(phoneNumber, message);
    if (success) return true;

    // Method 2: Try with platform channel (alternative method)
    success = await _sendViaPlatformChannel(phoneNumber, message);
    if (success) return true;

    // Method 3: Try with URL launcher (fallback method)
    success = await _sendViaUrlLauncher(phoneNumber, message);
    if (success) return true;

    print('All SMS sending methods failed for $phoneNumber');
    return false;
  }

  Future<bool> _sendViaTelephony(String phoneNumber, String message) async {
    try {
      // Check if SMS is available
      final bool? canSendSms = await _telephony.isSmsCapable;
      if (canSendSms != true) {
        print('Device is not SMS capable');
        return false;
      }

      // Try to send SMS with status listener
      final Completer<bool> completer = Completer<bool>();
      bool statusReceived = false;

      await _telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) {
          if (!statusReceived) {
            statusReceived = true;
            print('SMS Status: $status');

            if (status == SendStatus.SENT) {
              print(
                'SMS sent successfully via telephony package to $phoneNumber',
              );
              if (!completer.isCompleted) completer.complete(true);
            } else {
              print('SMS failed with status: $status');
              if (!completer.isCompleted) completer.complete(false);
            }
          }
        },
      );

      // Wait for status or timeout after 5 seconds
      return await completer.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SMS sending timeout - assuming success');
          return true; // Assume success if no status received
        },
      );
    } catch (e) {
      print('Error sending SMS via telephony: $e');
      return false;
    }
  }

  Future<bool> _sendViaPlatformChannel(
    String phoneNumber,
    String message,
  ) async {
    try {
      const platform = MethodChannel('emergency_sms');

      final result = await platform.invokeMethod('sendSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      });

      print('SMS sent via platform channel: $result');
      return result == true;
    } catch (e) {
      print('Error sending SMS via platform channel: $e');
      return false;
    }
  }

  Future<bool> _sendViaUrlLauncher(String phoneNumber, String message) async {
    try {
      // Create SMS URI
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        print('SMS app opened via URL launcher for $phoneNumber');
        return true;
      } else {
        print('Cannot launch SMS URI');
        return false;
      }
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
        print('Phone permission not granted, falling back to phone app');
        await _makeCallViaApp(phoneNumber);
        return;
      }

      bool? canCall = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (canCall == true) {
        print('Direct call initiated to $phoneNumber');
      } else {
        print('Direct call failed, falling back to phone app');
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

  // ENHANCED ALERT SOUND METHODS
  Future<void> playAlertSound() async {
    await startEmergencyAlertSound();
  }

  Future<void> startEmergencyAlertSound() async {
    if (_isPlayingEmergencySound) {
      print('Emergency sound already playing');
      return;
    }

    _isPlayingEmergencySound = true;
    print('🔊 Starting emergency alert sound');

    try {
      // Method 1: Try to play custom emergency sound from assets
      await _playCustomEmergencySound();

      // Method 2: If custom sound fails, use system sounds with repetition
      if (!await _isAudioPlaying()) {
        await _playSystemEmergencyAlerts();
      }

      // Method 3: Enhanced haptic feedback
      await _performEmergencyHaptics();
    } catch (e) {
      print('Error starting emergency sound: $e');
      // Fallback to basic system sounds
      await _playBasicSystemSounds();
    }
  }

  Future<void> _playCustomEmergencySound() async {
    try {
      // Try to play a custom emergency sound file from assets
      // You need to add an emergency sound file to your assets folder
      await _audioPlayer.setSource(AssetSource('sounds/emergency_alert.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.resume();

      print('✅ Custom emergency sound started');

      // Stop after 10 seconds to avoid infinite loop
      _soundTimer = Timer(Duration(seconds: 15), () {
        stopEmergencySound();
      });
    } catch (e) {
      print('Custom emergency sound failed: $e');
      // If asset doesn't exist, create a synthetic beeping sound
      await _createSyntheticEmergencySound();
    }
  }

  Future<void> _createSyntheticEmergencySound() async {
    try {
      // Create repeated beeping using system sounds
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

      // Stop after 15 seconds
      Timer(Duration(seconds: 15), () {
        stopEmergencySound();
      });
    } catch (e) {
      print('Error creating synthetic sound: $e');
    }
  }

  Future<void> _playSystemEmergencyAlerts() async {
    try {
      // Play multiple system alert sounds in sequence
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
      // Intense haptic feedback pattern for emergency
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
      // Fallback: basic system sounds
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

  // Play a single alert beep (for countdown)
  Future<void> playCountdownBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Error playing countdown beep: $e');
    }
  }

  // Play final countdown sound (more urgent)
  Future<void> playFinalCountdownSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error playing final countdown sound: $e');
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

  // Method to send emergency message immediately without UI
  Future<Map<String, bool>> sendEmergencyMessages(
    List<EmergencyContact> contacts,
    String emergencyMessage,
    bool smsPermissionGranted,
  ) async {
    Map<String, bool> results = {};

    print('🚨 EMERGENCY: Sending messages to ${contacts.length} contacts');

    // Sort contacts by priority
    final sortedContacts = List<EmergencyContact>.from(contacts)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (var contact in sortedContacts) {
      print(
        '🚨 Sending emergency SMS to ${contact.name} (Priority: ${contact.priority})',
      );

      bool success = await sendDirectSMS(
        contact.phoneNumber,
        emergencyMessage,
        smsPermissionGranted,
      );

      results[contact.phoneNumber] = success;

      if (success) {
        print('✅ Emergency SMS sent successfully to ${contact.name}');
      } else {
        print('❌ Failed to send emergency SMS to ${contact.name}');
      }

      // Small delay between messages
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Log final results
    int successCount = results.values.where((success) => success).length;
    int totalCount = results.length;
    print('🚨 Emergency messages sent: $successCount/$totalCount successful');

    return results;
  }

  // Enhanced permission checking
  Future<bool> checkAndRequestSmsPermission() async {
    try {
      var status = await Permission.sms.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.sms.request();
        return status.isGranted;
      }

      if (status.isPermanentlyDenied) {
        print('SMS permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      print('Error checking SMS permission: $e');
      return false;
    }
  }

  void dispose() {
    stopEmergencySound();
    _audioPlayer.dispose();
  }
}
