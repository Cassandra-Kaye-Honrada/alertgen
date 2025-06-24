// services/emergency/emergency_storage_service.dart - FIXED VERSION
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
    if (userId == null) {
      return {
        'contacts': <EmergencyContact>[],
        'settings': EmergencySettings(),
      };
    }

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
          contactsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Ensure ID is set
            return EmergencyContact.fromJson(data);
          }).toList();

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
    try {
      // Save to SharedPreferences first (faster, local)
      await _saveToSharedPreferences(contacts, settings);
      print('Settings saved to SharedPreferences');

      // Then save to Firebase (slower, network dependent)
      if (_auth.currentUser != null) {
        await _saveToFirebase(contacts, settings);
        print('Settings saved to Firebase');
      }

      print('Settings saved successfully to both locations');
    } catch (e) {
      print('Error saving settings: $e');
      // Ensure SharedPreferences is saved even if Firebase fails
      try {
        await _saveToSharedPreferences(contacts, settings);
        print('Fallback: Settings saved to SharedPreferences only');
      } catch (localError) {
        print('Critical error: Could not save to any storage: $localError');
        throw localError;
      }
    }
  }

  Future<void> _saveToFirebase(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in, skipping Firebase save');
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final contactsRef = userRef.collection('emergency_contacts');

      // Use a single transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        // Save settings first
        transaction.set(userRef, {
          'emergency_settings': settings.toJson(),
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Get existing contacts to delete them
        final existingContacts = await contactsRef.get();

        // Delete all existing contacts
        for (final doc in existingContacts.docs) {
          transaction.delete(doc.reference);
        }

        // Add new contacts
        for (int i = 0; i < contacts.length; i++) {
          final contact = contacts[i];
          final contactData = contact.toJson();
          // Remove the 'id' field since Firestore will generate it
          contactData.remove('id');
          // Set priority based on list order
          contactData['priority'] = i + 1;

          // Always create new documents to avoid conflicts
          final newDocRef = contactsRef.doc();
          transaction.set(newDocRef, contactData);
        }
      });

      print('Successfully saved to Firebase using transaction');
    } catch (e) {
      print('Error saving to Firebase: $e');
      throw e; // Re-throw to handle in the calling method
    }
  }

  Future<void> _saveToSharedPreferences(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save contacts
      final contactsJson = jsonEncode(
        contacts.map((contact) => contact.toJson()).toList(),
      );
      await prefs.setString('emergency_contacts', contactsJson);

      // Save settings
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString('emergency_settings', settingsJson);

      print('Successfully saved to SharedPreferences');
    } catch (e) {
      print('Error saving to SharedPreferences: $e');
      throw e; // Re-throw to handle in the calling method
    }
  }

  Future<void> syncOnLogin() async {
    if (_auth.currentUser != null) {
      try {
        await _loadFromFirebase();
        print('Sync completed successfully');
      } catch (e) {
        print('Error during sync: $e');
      }
    }
  }

  // Helper method to clear all data (useful for testing or logout)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emergency_contacts');
      await prefs.remove('emergency_settings');

      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userRef = _firestore.collection('users').doc(userId);
        final contactsRef = userRef.collection('emergency_contacts');

        final existingContacts = await contactsRef.get();
        final batch = _firestore.batch();

        for (final doc in existingContacts.docs) {
          batch.delete(doc.reference);
        }

        batch.update(userRef, {'emergency_settings': FieldValue.delete()});
        await batch.commit();
      }

      print('All data cleared successfully');
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}
