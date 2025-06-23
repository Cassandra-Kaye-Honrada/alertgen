// ===== 4. services/emergency/emergency_location_service.dart =====
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class EmergencyLocationService {
  Position? _currentPosition;
  Placemark? _currentPlacemark;

  Position? get currentPosition => _currentPosition;
  Placemark? get currentPlacemark => _currentPlacemark;
  void dispose() {
    // Clean up any resources like streams, listeners, etc.
    // Leave empty if no cleanup needed
  }
  Future<void> getCurrentLocationAndAddress() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      print(
        'Location obtained: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
      );

      if (_currentPosition != null) {
        await _getAddressFromCoordinates();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _getAddressFromCoordinates() async {
    if (_currentPosition == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        _currentPlacemark = placemarks.first;
        print(
          'Address found: ${formatPlacemarkForDisplay(_currentPlacemark!)}',
        );
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
    }
  }

  String formatPlacemarkForDisplay(Placemark placemark) {
    List<String> addressParts = [];

    if (placemark.name != null && placemark.name!.isNotEmpty) {
      addressParts.add(placemark.name!);
    }
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      addressParts.add(placemark.street!);
    }
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      addressParts.add(placemark.subLocality!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      addressParts.add(placemark.administrativeArea!);
    }
    if (placemark.country != null && placemark.country!.isNotEmpty) {
      addressParts.add(placemark.country!);
    }

    return addressParts.join(', ');
  }

  String createLocationMessage() {
    if (_currentPosition == null) {
      return '🚨 EMERGENCY: I need help!\n\nLocation: Unable to determine location.\n\nPlease call me immediately!';
    }

    StringBuffer message = StringBuffer();
    message.writeln('🚨 EMERGENCY: I need help!');
    message.writeln();

    if (_currentPlacemark != null) {
      String address = formatPlacemarkForDisplay(_currentPlacemark!);
      if (address.isNotEmpty) {
        message.writeln('📍 Address:');
        message.writeln(address);
        message.writeln();
      }
    }

    message.writeln('📍 Exact Coordinates:');
    message.writeln(
      'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
    );
    message.writeln(
      'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
    );
    message.writeln();
    message.writeln('⚠️ Please call me immediately or come to my location!');

    DateTime now = DateTime.now();
    message.writeln();
    message.writeln(
      '🕐 Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}',
    );

    return message.toString();
  }

  String getCurrentLocationInfo() {
    if (_currentPosition == null) {
      return 'Location not available';
    }

    if (_currentPlacemark != null) {
      String address = formatPlacemarkForDisplay(_currentPlacemark!);
      if (address.isNotEmpty) {
        return '$address\n\nCoordinates: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}';
      }
    }

    return 'Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }
}
