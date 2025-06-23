// ===== 6. services/emergency/emergency_storage_service.dart =====
import 'dart:convert';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:allergen/screens/models/emergency_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  void dispose() {
    // Clean up any resources here
    // For example, if you have streams or listeners:
    // _streamSubscription?.cancel();
    // _timer?.cancel();
  }
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      if (_auth.currentUser != null) {
        return await _loadFromFirebase();
      } else {
        return await _loadFromSharedPreferences();
      }
    } catch (e) {
      print('Error loading settings: $e');
      return await _loadFromSharedPreferences();
    }
  }

  Future<Map<String, dynamic>> _loadFromFirebase() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null)
      return {
        'contacts': <EmergencyContact>[],
        'settings': EmergencySettings(),
      };

    try {
      // Load contacts
      final contactsSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('emergency_contacts')
              .orderBy('priority')
              .get();

      List<EmergencyContact> contacts =
          contactsSnapshot.docs
              .map(
                (doc) =>
                    EmergencyContact.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList();

      // Load settings
      final settingsDoc =
          await _firestore.collection('users').doc(userId).get();
      EmergencySettings settings = EmergencySettings();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null && data.containsKey('emergency_settings')) {
          settings = EmergencySettings.fromJson(data['emergency_settings']);
        }
      }

      // Backup to SharedPreferences
      await _saveToSharedPreferences(contacts, settings);

      return {'contacts': contacts, 'settings': settings};
    } catch (e) {
      print('Error loading from Firebase: $e');
      return await _loadFromSharedPreferences();
    }
  }

  Future<Map<String, dynamic>> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      List<EmergencyContact> contacts = [];
      EmergencySettings settings = EmergencySettings();

      // Load contacts
      final contactsJson = prefs.getString('emergency_contacts');
      if (contactsJson != null) {
        final contactsList = jsonDecode(contactsJson) as List;
        contacts =
            contactsList
                .map((json) => EmergencyContact.fromJson(json))
                .toList();
      }

      // Load settings
      final settingsJson = prefs.getString('emergency_settings');
      if (settingsJson != null) {
        settings = EmergencySettings.fromJson(jsonDecode(settingsJson));
      }

      return {'contacts': contacts, 'settings': settings};
    } catch (e) {
      print('Error loading from SharedPreferences: $e');
      return {
        'contacts': <EmergencyContact>[],
        'settings': EmergencySettings(),
      };
    }
  }

  Future<void> saveSettings(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    await Future.wait([
      _saveToFirebase(contacts, settings),
      _saveToSharedPreferences(contacts, settings),
    ]);
  }

  Future<void> _saveToFirebase(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final contactsRef = userRef.collection('emergency_contacts');

      // Save settings
      await userRef.set({
        'emergency_settings': settings.toJson(),
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save contacts
      final existingContacts = await contactsRef.get();
      final batch = _firestore.batch();

      for (final doc in existingContacts.docs) {
        batch.delete(doc.reference);
      }

      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        final contactData = contact.toJson();
        contactData['priority'] = i;
        batch.set(contactsRef.doc(), contactData);
      }

      await batch.commit();
    } catch (e) {
      print('Error saving to Firebase: $e');
    }
  }

  Future<void> _saveToSharedPreferences(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final contactsJson = jsonEncode(
        contacts.map((contact) => contact.toJson()).toList(),
      );
      await prefs.setString('emergency_contacts', contactsJson);

      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString('emergency_settings', settingsJson);
    } catch (e) {
      print('Error saving to SharedPreferences: $e');
    }
  }

  Future<void> syncOnLogin() async {
    if (_auth.currentUser != null) {
      await _loadFromFirebase();
    }
  }
}
