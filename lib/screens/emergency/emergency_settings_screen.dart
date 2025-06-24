import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:allergen/widgets/emergency_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_settings.dart';

class EmergencySettingsScreen extends StatefulWidget {
  final List<EmergencyContact> emergencyContacts;
  final EmergencySettings emergencySettings;
  final EmergencyService emergencyService;
  final Function(List<EmergencyContact>, EmergencySettings) onSave;

  const EmergencySettingsScreen({
    Key? key,
    required this.emergencyContacts,
    required this.emergencySettings,
    required this.emergencyService,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EmergencySettingsScreen> createState() =>
      _EmergencySettingsScreenState();
}

class _EmergencySettingsScreenState extends State<EmergencySettingsScreen> {
  late List<EmergencyContact> _contacts;
  late EmergencySettings _settings;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNumberController = TextEditingController();
  final _searchController = TextEditingController();

  bool _hasUnsavedChanges = false;
  List<Contact> _phoneContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.emergencyContacts);
    _settings = widget.emergencySettings.copyWith();
    _emergencyNumberController.text = _settings.emergencyServiceNumber;
  }

  void _markAsChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  Future<void> _requestContactsPermission() async {
    final permission = await FlutterContacts.requestPermission();
    if (permission) {
      await _loadPhoneContacts();
    } else {
      _showPermissionDialog();
    }
  }

  Future<void> _loadPhoneContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        _phoneContacts =
            contacts
                .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
                .toList()
              ..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              );
        _filteredContacts = List.from(_phoneContacts);
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() => _isLoadingContacts = false);
      _showSnackBar('Error loading contacts: $e', Colors.red);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts =
          query.isEmpty
              ? List.from(_phoneContacts)
              : _phoneContacts
                  .where(
                    (c) =>
                        c.displayName.toLowerCase().contains(
                          query.toLowerCase(),
                        ) ||
                        c.phones.any(
                          (p) => p.number
                              .replaceAll(RegExp(r'[^\d+]'), '')
                              .contains(query),
                        ),
                  )
                  .toList();
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Contacts Permission Required'),
            content: const Text(
              'Grant contacts permission to import contacts from your phone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _requestContactsPermission();
                },
                child: const Text('Grant Permission'),
              ),
            ],
          ),
    );
  }

  void _showContactImportDialog() async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      await _requestContactsPermission();
      return;
    }

    if (_phoneContacts.isEmpty) await _loadPhoneContacts();
    _searchController.clear();
    _filteredContacts = List.from(_phoneContacts);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Import from Contacts'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 400,
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search contacts',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            _filterContacts(value);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child:
                              _isLoadingContacts
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : _filteredContacts.isEmpty
                                  ? const Center(
                                    child: Text('No contacts found'),
                                  )
                                  : ListView.builder(
                                    itemCount: _filteredContacts.length,
                                    itemBuilder: (context, index) {
                                      final contact = _filteredContacts[index];
                                      return ExpansionTile(
                                        leading: CircleAvatar(
                                          child: Text(
                                            contact.displayName[0]
                                                .toUpperCase(),
                                          ),
                                        ),
                                        title: Text(contact.displayName),
                                        subtitle: Text(
                                          '${contact.phones.length} phone number(s)',
                                        ),
                                        children:
                                            contact.phones.map((phone) {
                                              final phoneNumber = phone.number
                                                  .replaceAll(
                                                    RegExp(r'[^\d+]'),
                                                    '',
                                                  );
                                              final isAdded = _contacts.any(
                                                (c) =>
                                                    c.phoneNumber ==
                                                    phoneNumber,
                                              );
                                              return ListTile(
                                                title: Text(phoneNumber),
                                                subtitle: Text(
                                                  phone.label.toString(),
                                                ),
                                                trailing:
                                                    isAdded
                                                        ? const Icon(
                                                          Icons.check,
                                                          color: Colors.green,
                                                        )
                                                        : IconButton(
                                                          icon: const Icon(
                                                            Icons.add,
                                                          ),
                                                          onPressed: () {
                                                            _addContactFromPhone(
                                                              contact
                                                                  .displayName,
                                                              phoneNumber,
                                                            );
                                                            setState(() {});
                                                          },
                                                        ),
                                              );
                                            }).toList(),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _addContactFromPhone(String name, String phoneNumber) {
    if (_contacts.any((c) => c.phoneNumber == phoneNumber)) {
      _showSnackBar('Contact already exists', Colors.orange);
      return;
    }

    setState(() {
      _contacts.add(
        EmergencyContact(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          phoneNumber: phoneNumber,
          priority: _contacts.length + 1,
          sendLocationSMS: true,
        ),
      );
      _markAsChanged();
    });
    _showSnackBar('$name added to emergency contacts', Colors.green);
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Emergency Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final phone = _phoneController.text.trim();

                  if (name.isEmpty || phone.isEmpty) {
                    _showSnackBar(
                      'Please fill in all required fields',
                      Colors.red,
                    );
                    return;
                  }

                  if (_contacts.any((c) => c.phoneNumber == phone)) {
                    _showSnackBar(
                      'This phone number already exists',
                      Colors.red,
                    );
                    return;
                  }

                  setState(() {
                    _contacts.add(
                      EmergencyContact(
                        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        phoneNumber: phone,
                        priority: _contacts.length + 1,
                        sendLocationSMS: true,
                      ),
                    );
                    _markAsChanged();
                  });

                  _nameController.clear();
                  _phoneController.clear();
                  Navigator.pop(context);
                },
                child: const Text('Add'),
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
            title: const Text('Edit Contact'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    prefixText: '+',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Send Location SMS'),
                  value: contact.sendLocationSMS,
                  onChanged: (value) {
                    setState(() {
                      final index = _contacts.indexWhere(
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final phone = _phoneController.text.trim();

                  if (name.isEmpty || phone.isEmpty) {
                    _showSnackBar(
                      'Please fill in all required fields',
                      Colors.red,
                    );
                    return;
                  }

                  if (_contacts.any(
                    (c) => c.phoneNumber == phone && c.id != contact.id,
                  )) {
                    _showSnackBar(
                      'This phone number already exists',
                      Colors.red,
                    );
                    return;
                  }

                  setState(() {
                    final index = _contacts.indexWhere(
                      (c) => c.id == contact.id,
                    );
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
                child: const Text('Save'),
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
            title: const Text('Delete Contact'),
            content: Text('Remove "${contact.name}" from emergency contacts?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _contacts.removeWhere((c) => c.id == contact.id);
                    for (int i = 0; i < _contacts.length; i++) {
                      _contacts[i] = _contacts[i].copyWith(priority: i + 1);
                    }
                    _markAsChanged();
                  });
                  _showSnackBar('${contact.name} removed', Colors.red);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _reorderContacts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final contact = _contacts.removeAt(oldIndex);
      _contacts.insert(newIndex, contact);
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _saveSettings() async {
    final emergencyNumber = _emergencyNumberController.text.trim();
    if (emergencyNumber.isNotEmpty) {
      _settings = _settings.copyWith(emergencyServiceNumber: emergencyNumber);
    }

    try {
      widget.onSave(_contacts, _settings);
      setState(() => _hasUnsavedChanges = false);
      _showSnackBar('Settings saved successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Error saving settings. Please try again.', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final result = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Unsaved Changes'),
                  content: const Text(
                    'You have unsaved changes. Save before leaving?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Discard'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _saveSettings();
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save & Exit'),
                    ),
                  ],
                ),
          );
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.defaultbackground,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text(
            'Emergency Contacts',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save, color: Colors.white),
                tooltip: 'Save Changes',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              EmergencyWidget(
                emergencyService: widget.emergencyService,
                showSettings: false,
                showStatus: true,
              ),
              const SizedBox(height: 24),
              _buildContactsSection(),
              const SizedBox(height: 16),
              _buildSettingsSection(),
              const SizedBox(height: 24),
              if (_hasUnsavedChanges)
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save All Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emergency Contacts (${_contacts.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showContactImportDialog,
                      icon: const Icon(Icons.contacts),
                      label: const Text('Import'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddContactDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_contacts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.contacts, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No emergency contacts added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _contacts.length,
                onReorder: _reorderContacts,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return Card(
                    key: ValueKey(contact.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          '${contact.priority}',
                          style: const TextStyle(
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
                            const Text(
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
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: () => _deleteContact(contact),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                          const Icon(Icons.drag_handle, color: Colors.grey),
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

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Auto-send location to all contacts'),
              value: _settings.autoSendLocationToAll,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.autoSendLocationToAll,
                    (v) => _settings.copyWith(autoSendLocationToAll: v),
                  ),
            ),
            SwitchListTile(
              title: const Text('Play alert sound'),
              value: _settings.playAlertSound,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.playAlertSound,
                    (v) => _settings.copyWith(playAlertSound: v),
                  ),
            ),
            SwitchListTile(
              title: const Text('Auto-call emergency services'),
              value: _settings.autoCallEmergencyServices,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (s) => s.autoCallEmergencyServices,
                    (v) => _settings.copyWith(autoCallEmergencyServices: v),
                  ),
            ),
            ListTile(
              title: const Text('Call timeout'),
              trailing: DropdownButton<int>(
                value: _settings.callTimeoutSeconds,
                items:
                    [15, 30, 45, 60]
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text('${s}s')),
                        )
                        .toList(),
                onChanged:
                    (value) =>
                        value != null
                            ? _updateSetting(
                              value,
                              (s) => s.callTimeoutSeconds,
                              (v) => _settings.copyWith(callTimeoutSeconds: v),
                            )
                            : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _emergencyNumberController,
                decoration: const InputDecoration(
                  labelText: 'Emergency Service Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.emergency),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (_) => _markAsChanged(),
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
    _searchController.dispose();
    super.dispose();
  }
}
