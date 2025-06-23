// ===== 3. services/emergency/emergency_permission_service.dart =====
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class EmergencyPermissionService {
  final Telephony _telephony = Telephony.instance;
  void dispose() {
    // Clean up any resources like streams, listeners, etc.
    // Leave empty if no cleanup needed
  }
  bool _smsPermissionGranted = false;
  bool _phonePermissionGranted = false;
  bool _locationPermissionGranted = false;

  // Getters
  bool get smsPermissionGranted => _smsPermissionGranted;
  bool get phonePermissionGranted => _phonePermissionGranted;
  bool get locationPermissionGranted => _locationPermissionGranted;
  bool get allPermissionsGranted =>
      _smsPermissionGranted && _phonePermissionGranted;

  Future<void> requestAllPermissions() async {
    try {
      await _requestSmsPermissions();
      await _requestPhonePermissions();
      await _requestLocationPermissions();

      print(
        'Permissions - SMS: $_smsPermissionGranted, Phone: $_phonePermissionGranted, Location: $_locationPermissionGranted',
      );
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _requestSmsPermissions() async {
    PermissionStatus smsStatus = await Permission.sms.status;
    if (!smsStatus.isGranted) {
      smsStatus = await Permission.sms.request();
    }
    _smsPermissionGranted = smsStatus.isGranted;

    if (!_smsPermissionGranted) {
      bool? telephonyPermission =
          await _telephony.requestPhoneAndSmsPermissions;
      _smsPermissionGranted = telephonyPermission == true;
    }
  }

  Future<void> _requestPhonePermissions() async {
    PermissionStatus phoneStatus = await Permission.phone.status;
    if (!phoneStatus.isGranted) {
      phoneStatus = await Permission.phone.request();
    }
    _phonePermissionGranted = phoneStatus.isGranted;
  }

  Future<void> _requestLocationPermissions() async {
    PermissionStatus locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
    }
    _locationPermissionGranted = locationStatus.isGranted;

    if (!_locationPermissionGranted) {
      LocationPermission geoPermission = await Geolocator.checkPermission();
      if (geoPermission == LocationPermission.denied) {
        geoPermission = await Geolocator.requestPermission();
      }
      _locationPermissionGranted =
          geoPermission == LocationPermission.whileInUse ||
          geoPermission == LocationPermission.always;
    }
  }

  Future<bool> showPermissionDialog(BuildContext context) async {
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
                if (!_smsPermissionGranted)
                  _buildPermissionRow(
                    Icons.message,
                    'SMS - to send location messages',
                    Colors.red,
                  ),
                if (!_phonePermissionGranted)
                  _buildPermissionRow(
                    Icons.phone,
                    'Phone - to make emergency calls',
                    Colors.red,
                  ),
                if (!_locationPermissionGranted)
                  _buildPermissionRow(
                    Icons.location_on,
                    'Location - to share your location',
                    Colors.orange,
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
                  await requestAllPermissions();
                },
                child: Text('Grant Permissions'),
              ),
            ],
          ),
    );
    return result == true;
  }

  Widget _buildPermissionRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
