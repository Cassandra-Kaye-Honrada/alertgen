// screens/emergency_settings_screen.dart
import 'package:allergen/styleguide.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/widgets/emergency_widget.dart';
import 'package:flutter/material.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_settings.dart';

class EmergencySettingsScreen extends StatefulWidget {
  final List<EmergencyContact> emergencyContacts;
  final EmergencySettings emergencySettings;
  final EmergencyService emergencyService; // Add this parameter
  final Function(List<EmergencyContact>, EmergencySettings) onSave;

  const EmergencySettingsScreen({
    Key? key,
    required this.emergencyContacts,
    required this.emergencySettings,
    required this.emergencyService, // Add this parameter
    required this.onSave,
  }) : super(key: key);

  @override
  _EmergencySettingsScreenState createState() =>
      _EmergencySettingsScreenState();
}

class _EmergencySettingsScreenState extends State<EmergencySettingsScreen> {
  late List<EmergencyContact> _contacts;
  late EmergencySettings _settings;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyNumberController =
      TextEditingController();

  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.emergencyContacts);
    _settings = widget.emergencySettings.copyWith(); // Make a copy
    _emergencyNumberController.text = _settings.emergencyServiceNumber;
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  void _addContact() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Emergency Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    prefixText: '+',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _nameController.clear();
                  _phoneController.clear();
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final phone = _phoneController.text.trim();

                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please fill in all required fields'),
                      ),
                    );
                    return;
                  }

                  // Check for duplicate phone numbers
                  if (_contacts.any((c) => c.phoneNumber == phone)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('This phone number already exists'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _contacts.add(
                      EmergencyContact(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        phoneNumber: phone,
                        priority: _contacts.length + 1,
                        sendLocationSMS: true, // Default to true
                      ),
                    );
                    _markAsChanged();
                  });

                  _nameController.clear();
                  _phoneController.clear();
                  Navigator.pop(context);
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  void _editContact(EmergencyContact contact) {
    _nameController.text = contact.name;
    _phoneController.text = contact.phoneNumber;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    prefixText: '+',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Send Location SMS'),
                  subtitle: Text('Include location in emergency messages'),
                  value: contact.sendLocationSMS,
                  onChanged: (value) {
                    setState(() {
                      int index = _contacts.indexWhere(
                        (c) => c.id == contact.id,
                      );
                      if (index != -1) {
                        _contacts[index] = _contacts[index].copyWith(
                          sendLocationSMS: value,
                        );
                        _markAsChanged();
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _nameController.clear();
                  _phoneController.clear();
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final phone = _phoneController.text.trim();

                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please fill in all required fields'),
                      ),
                    );
                    return;
                  }

                  // Check for duplicate phone numbers (excluding current contact)
                  if (_contacts.any(
                    (c) => c.phoneNumber == phone && c.id != contact.id,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('This phone number already exists'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    int index = _contacts.indexWhere((c) => c.id == contact.id);
                    if (index != -1) {
                      _contacts[index] = _contacts[index].copyWith(
                        name: name,
                        phoneNumber: phone,
                      );
                      _markAsChanged();
                    }
                  });

                  _nameController.clear();
                  _phoneController.clear();
                  Navigator.pop(context);
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  void _deleteContact(EmergencyContact contact) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Contact'),
            content: Text('Remove "${contact.name}" from emergency contacts?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _contacts.removeWhere((c) => c.id == contact.id);
                    // Reorder priorities
                    for (int i = 0; i < _contacts.length; i++) {
                      _contacts[i] = _contacts[i].copyWith(priority: i + 1);
                    }
                    _markAsChanged();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${contact.name} removed')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _reorderContacts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final contact = _contacts.removeAt(oldIndex);
      _contacts.insert(newIndex, contact);

      // Update priorities
      for (int i = 0; i < _contacts.length; i++) {
        _contacts[i] = _contacts[i].copyWith(priority: i + 1);
      }
      _markAsChanged();
    });
  }

  void _updateSetting<T>(
    T value,
    T Function(EmergencySettings) getter,
    EmergencySettings Function(T) updater,
  ) {
    if (getter(_settings) != value) {
      setState(() {
        _settings = updater(value);
        _markAsChanged();
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Unsaved Changes'),
            content: Text(
              'You have unsaved changes. What would you like to do?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Keep Editing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Discard Changes'),
              ),
              ElevatedButton(
                onPressed: () {
                  _saveSettings();
                  Navigator.of(context).pop(true);
                },
                child: Text('Save & Exit'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  void _saveSettings() {
    // Update emergency service number from controller
    final emergencyNumber = _emergencyNumberController.text.trim();
    if (emergencyNumber.isNotEmpty) {
      _settings = _settings.copyWith(emergencyServiceNumber: emergencyNumber);
    }

    widget.onSave(_contacts, _settings);
    setState(() {
      _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.defaultbackground,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          title: const Text(
            'Emergency Contacts',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                onPressed: _saveSettings,
                icon: Icon(Icons.save),
                tooltip: 'Save Changes',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergency Widget Section
              EmergencyWidget(
                emergencyService: widget.emergencyService,
                showSettings:
                    false, // Hide settings since we're in settings screen
                showStatus: true,
              ),
              SizedBox(height: 24),

              // Emergency Contacts Section
              _buildContactsSection(),
              SizedBox(height: 16),

              // Location Settings
              _buildLocationSettings(),
              SizedBox(height: 16),

              // Call Settings
              _buildCallSettings(),
              SizedBox(height: 16),

              // Interface Settings
              _buildInterfaceSettings(),
              SizedBox(height: 24),

              // Save Button
              if (_hasUnsavedChanges)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: Icon(Icons.save),
                    label: Text('Save All Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emergency Contacts (${_contacts.length})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addContact,
                  icon: Icon(Icons.add),
                  label: Text('Add'),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_contacts.isEmpty)
              Container(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.contacts, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No emergency contacts added yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _contacts.length,
                onReorder: _reorderContacts,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return Card(
                    key: ValueKey(contact.id),
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          '${contact.priority}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(contact.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(contact.phoneNumber),
                          if (contact.sendLocationSMS)
                            Text(
                              '📍 Location SMS enabled',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editContact(contact),
                            icon: Icon(Icons.edit),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            onPressed: () => _deleteContact(contact),
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                          ),
                          Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSettings() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SwitchListTile(
              title: Text('Send location to all contacts'),
              subtitle: Text(
                'Automatically send SMS with location to all emergency contacts',
              ),
              value: _settings.autoSendLocationToAll,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.autoSendLocationToAll,
                    (v) => _settings.copyWith(autoSendLocationToAll: v),
                  ),
            ),
            SwitchListTile(
              title: Text('Send location to current contact'),
              subtitle: Text(
                'Send SMS with location to the contact being called',
              ),
              value: _settings.autoSendLocationToCurrentContact,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.autoSendLocationToCurrentContact,
                    (v) =>
                        _settings.copyWith(autoSendLocationToCurrentContact: v),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallSettings() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Call Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SwitchListTile(
              title: Text('Play alert sound'),
              subtitle: Text('Play sound before making emergency calls'),
              value: _settings.playAlertSound,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.playAlertSound,
                    (v) => _settings.copyWith(playAlertSound: v),
                  ),
            ),
            SwitchListTile(
              title: Text('Auto-call emergency services'),
              subtitle: Text(
                'Automatically call emergency services if no contacts respond',
              ),
              value: _settings.autoCallEmergencyServices,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.autoCallEmergencyServices,
                    (v) => _settings.copyWith(autoCallEmergencyServices: v),
                  ),
            ),
            ListTile(
              title: Text('Call timeout'),
              subtitle: Text('Time to wait before trying next contact'),
              trailing: DropdownButton<int>(
                value: _settings.callTimeoutSeconds,
                items:
                    [15, 30, 45, 60].map((seconds) {
                      return DropdownMenuItem(
                        value: seconds,
                        child: Text('${seconds}s'),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _updateSetting(
                      value,
                      (s) => s.callTimeoutSeconds,
                      (v) => _settings.copyWith(callTimeoutSeconds: v),
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _emergencyNumberController,
                decoration: InputDecoration(
                  labelText: 'Emergency Service Number',
                  border: OutlineInputBorder(),
                  helperText: 'Number to call when all contacts are exhausted',
                  prefixIcon: Icon(Icons.emergency),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => _markAsChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfaceSettings() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interface Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SwitchListTile(
              title: Text('Enable drag to cancel'),
              subtitle: Text('Allow dragging down to cancel emergency call'),
              value: _settings.enableDragToCancel,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.enableDragToCancel,
                    (v) => _settings.copyWith(enableDragToCancel: v),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyNumberController.dispose();
    super.dispose();
  }
}
