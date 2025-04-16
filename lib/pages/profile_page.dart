// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../providers/profile_provider.dart';
import '../widgets/drawer_menu.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Form and Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  // Controllers used only within dialogs now
  // final _newAllergyController = TextEditingController(); // Defined locally in dialog
  // final _newConditionController = TextEditingController(); // Defined locally in dialog

  // Local State for form selections
  String _selectedGender = '';
  String _selectedBloodType = '';
  DateTime? _selectedDate;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeStateFromProvider();
  }

  // Load initial data when entering view or edit mode
  void _initializeStateFromProvider() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    _nameController.text = profileProvider.name;
    _selectedGender = profileProvider.gender;
    _selectedBloodType = profileProvider.bloodType;
    _selectedDate = profileProvider.dateOfBirth;
    _weightController.text = profileProvider.weight > 0
        ? profileProvider.weight.toStringAsFixed(1)
        : '';
    _heightController.text = profileProvider.height > 0
        ? profileProvider.height.toStringAsFixed(0)
        : '';
    // Reset editing state flags
    _isEditing = false;
    _isSaving = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    // _newAllergyController.dispose(); // No longer needed here
    // _newConditionController.dispose(); // No longer needed here
    super.dispose();
  }

  // --- Snackbar Helper ---
  void _showSnackbar(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? Colors.green.shade600
            : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    // Listen for rebuilds if profile data could change externally while viewing
    final profileProvider = Provider.of<ProfileProvider>(context);
    final bool hasProfileData = profileProvider.name.isNotEmpty ||
        profileProvider.dateOfBirth != null ||
        profileProvider.height > 0 ||
        profileProvider.weight > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'My Profile'),
        elevation: 1.0,
        actions: _buildAppBarActions(hasProfileData, profileProvider),
      ),
      drawer: const DrawerMenu(currentRoute: '/profile'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : _isEditing
                ? _buildProfileForm(context, profileProvider)
                : (hasProfileData
                    ? _buildProfileView(context, profileProvider)
                    : _buildEmptyProfileView(context)),
      ),
      floatingActionButton: (!_isEditing && hasProfileData)
          ? FloatingActionButton.extended(
              onPressed: () {
                if (mounted) {
                  _initializeStateFromProvider();
                  setState(() => _isEditing = true);
                }
              }, // Ensure state is fresh before editing
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile'),
            )
          : null,
    );
  }

  List<Widget> _buildAppBarActions(
      bool hasProfileData, ProfileProvider profileProvider) {
    if (_isEditing) {
      return [
        IconButton(
          icon: const Icon(Icons.cancel_outlined),
          onPressed: () {
            if (mounted) {
              setState(() {
                _isEditing = false;
                _initializeStateFromProvider();
              });
            }
          },
          tooltip: 'Cancel',
        ),
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: _saveProfile,
          tooltip: 'Save Profile',
        ),
      ];
    } else if (hasProfileData) {
      return [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: _confirmClearProfile,
          tooltip: 'Clear Profile Data',
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {
            if (mounted) {
              _initializeStateFromProvider();
              setState(() => _isEditing = true);
            }
          },
          tooltip: 'Edit Profile',
        ),
      ];
    } else {
      return [
        IconButton(
          icon:
              const Icon(Icons.add_circle_outline), // Use add icon for creating
          onPressed: () {
            if (mounted) {
              _initializeStateFromProvider();
              setState(() => _isEditing = true);
            }
          },
          tooltip: 'Create Profile',
        ),
      ];
    }
  }

  // --- Profile View Mode (Read Only) ---

  Widget _buildEmptyProfileView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined,
                size: 80, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text('No Profile Data',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Tap the button below to create your profile.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (mounted) {
                  _initializeStateFromProvider();
                  setState(() => _isEditing = true);
                }
              }, // Enter edit mode
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView(
      BuildContext context, ProfileProvider profileProvider) {
    return RefreshIndicator(
      onRefresh: () async {
        if (mounted) setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileHeader(context, profileProvider),
          const SizedBox(height: 16),
          _buildBasicInfoSection(context, profileProvider),
          const SizedBox(height: 16),
          _buildReadOnlyListSection(
            context: context,
            title: 'Medical Conditions',
            icon: Icons.medical_information_outlined,
            items: profileProvider.medicalConditions
                .where((c) => c.selected)
                .map((c) => c.name)
                .toList(),
            chipColor: Theme.of(context).colorScheme.primary,
            chipIcon: Icons.local_hospital_outlined,
            emptyText: 'No conditions specified',
          ),
          const SizedBox(height: 16),
          _buildReadOnlyListSection(
            context: context,
            title: 'Allergies',
            icon: Icons.sick_outlined,
            iconColor: Theme.of(context).colorScheme.error,
            items: profileProvider.allergies,
            chipColor: Theme.of(context).colorScheme.error,
            chipIcon: Icons.warning_amber_rounded,
            emptyText: 'No allergies specified',
          ),
          const SizedBox(height: 16),
          _buildReadOnlyListSection(
            context: context,
            title: 'Current Medications',
            icon: Icons.medication_outlined,
            iconColor: Colors.orange.shade700,
            items: profileProvider.medications
                .map((m) => '${m.name} (${m.dosage} - ${m.frequency})')
                .toList(),
            emptyText: 'No medications specified',
            useChips: false,
          ),
          const SizedBox(height: 16),
          _buildReadOnlyListSection(
            context: context,
            title: 'Emergency Contacts',
            icon: Icons.contact_emergency_outlined,
            iconColor: Theme.of(context).colorScheme.secondary,
            items: profileProvider.emergencyContacts
                .map((c) =>
                    '${c.name}${c.relationship.isNotEmpty ? ' (${c.relationship})' : ''}: ${c.phoneNumber}')
                .toList(),
            emptyText: 'No contacts specified',
            useChips: false,
          ),
        ],
      ),
    );
  }

  // Builds the header section in view mode
  Widget _buildProfileHeader(
      BuildContext context, ProfileProvider profileProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Hero(
            tag: 'profileAvatar',
            child: CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                    profileProvider.name.isNotEmpty
                        ? profileProvider.name[0].toUpperCase()
                        : "?",
                    style: textTheme.headlineLarge
                        ?.copyWith(color: colorScheme.onPrimaryContainer)))),
        const SizedBox(height: 16),
        Text(
            profileProvider.name.isNotEmpty
                ? profileProvider.name
                : "User Profile",
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center),
        if (profileProvider.age != null) ...[
          const SizedBox(height: 4),
          Text('${profileProvider.age} years old',
              style:
                  textTheme.titleMedium?.copyWith(color: colorScheme.secondary))
        ],
        if (profileProvider.bmi != null) ...[
          const SizedBox(height: 8),
          Chip(
              label: Text(
                  'BMI: ${profileProvider.bmi!.toStringAsFixed(1)} (${profileProvider.bmiCategory})',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSecondaryContainer)),
              backgroundColor: colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              visualDensity: VisualDensity.compact)
        ],
      ]),
    );
  }

  // Builds the basic info section in view mode
  Widget _buildBasicInfoSection(
      BuildContext context, ProfileProvider profileProvider) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Basic Information',
              style: Theme.of(context).textTheme.titleLarge),
          const Divider(height: 24),
          if (profileProvider.name.isNotEmpty)
            _buildInfoRow('Name', profileProvider.name, Icons.person_outline),
          if (profileProvider.dateOfBirth != null)
            _buildInfoRow(
                'Date of Birth',
                DateFormat.yMMMMd().format(profileProvider.dateOfBirth!),
                Icons.calendar_today_outlined),
          if (profileProvider.gender.isNotEmpty)
            _buildInfoRow('Gender', profileProvider.gender, Icons.wc_outlined),
          if (profileProvider.height > 0)
            _buildInfoRow(
                'Height',
                '${profileProvider.height.toStringAsFixed(0)} cm',
                Icons.height_outlined),
          if (profileProvider.weight > 0)
            _buildInfoRow(
                'Weight',
                '${profileProvider.weight.toStringAsFixed(1)} kg',
                Icons.monitor_weight_outlined),
          if (profileProvider.bloodType.isNotEmpty &&
              profileProvider.bloodType != 'Unknown')
            _buildInfoRow('Blood Type', profileProvider.bloodType,
                Icons.bloodtype_outlined),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Generic helper for displaying lists in read-only view mode
  Widget _buildReadOnlyListSection(
      {required BuildContext context,
      required String title,
      required IconData icon,
      required List<String> items,
      required String emptyText,
      Color? iconColor,
      Color? chipColor,
      IconData? chipIcon,
      bool useChips = true}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final effectiveChipColor = chipColor ?? colorScheme.primary;
    final chipTextColor = useChips
        ? (ThemeData.estimateBrightnessForColor(effectiveChipColor) ==
                Brightness.dark
            ? Colors.white
            : Colors.black)
        : colorScheme.onSurface;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: effectiveIconColor),
            const SizedBox(width: 12),
            Text(title, style: theme.textTheme.titleLarge)
          ]),
          const Divider(height: 24),
          if (items.isNotEmpty)
            useChips
                ? Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: items
                        .map((item) => Chip(
                              avatar: chipIcon != null
                                  ? Icon(chipIcon,
                                      size: 16, color: chipTextColor)
                                  : null,
                              backgroundColor: effectiveChipColor,
                              label: Text(item,
                                  style: TextStyle(color: chipTextColor)),
                            ))
                        .toList())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items
                        .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text('• $item',
                                style: theme.textTheme.bodyLarge)))
                        .toList())
          else
            Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(emptyText,
                        style: const TextStyle(color: Colors.grey)))),
        ]),
      ),
    );
  }

  // Helper to display a single row of info in view mode
  Widget _buildInfoRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: theme.colorScheme.secondary),
        const SizedBox(width: 16),
        Text('$label: ',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Expanded(
            child: Text(value,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // --- Profile Edit Form ---

  Widget _buildProfileForm(
      BuildContext context, ProfileProvider profileProvider) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Basic Info
            _buildEditSectionHeader('Basic Information'),
            TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Full Name', Icons.person_outline),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Name required' : null,
                textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            InkWell(
                onTap: () => _selectDate(context, profileProvider),
                child: InputDecorator(
                    decoration: _inputDecoration(
                        'Date of Birth', Icons.calendar_today_outlined,
                        isDropdown: true),
                    child: Text(
                        _selectedDate != null
                            ? DateFormat.yMMMMd().format(_selectedDate!)
                            : 'Select date',
                        style: textTheme.titleMedium?.copyWith(height: 1.3) ??
                            const TextStyle(height: 1.3)))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
                value: _selectedGender.isEmpty ? null : _selectedGender,
                decoration: _inputDecoration('Gender', Icons.wc_outlined),
                hint: const Text('Select gender'),
                items: ['Male', 'Female', 'Other', 'Prefer not to say']
                    .map((g) =>
                        DropdownMenuItem<String>(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) {
                  if (v != null && mounted) setState(() => _selectedGender = v);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Gender required' : null),
            const SizedBox(height: 24),
            // Health Metrics
            _buildEditSectionHeader('Health Metrics'),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _heightController,
                      decoration: _inputDecoration(
                          'Height (cm)', Icons.height_outlined),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => _validateNumber(v, 0, 300, 'Height'))),
              const SizedBox(width: 16),
              Expanded(
                  child: TextFormField(
                      controller: _weightController,
                      decoration: _inputDecoration(
                          'Weight (kg)', Icons.monitor_weight_outlined),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,1}'))
                      ],
                      validator: (v) => _validateNumber(v, 0, 500, 'Weight'))),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
                value: _selectedBloodType.isEmpty ? null : _selectedBloodType,
                decoration:
                    _inputDecoration('Blood Type', Icons.bloodtype_outlined),
                hint: const Text('Select blood type'),
                items: [
                  'A+',
                  'A-',
                  'B+',
                  'B-',
                  'AB+',
                  'AB-',
                  'O+',
                  'O-',
                  'Unknown'
                ]
                    .map((t) =>
                        DropdownMenuItem<String>(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) {
                  if (v != null && mounted)
                    setState(() => _selectedBloodType = v);
                }),
            const SizedBox(height: 24),
            // Editable Lists Sections
            _buildEditableListSection(
                context: context,
                title: 'Medical Conditions',
                icon: Icons.medical_information_outlined,
                items: profileProvider.medicalConditions
                    .where((c) => c.selected)
                    .map((c) => c.name)
                    .toList(),
                onAddItem: () =>
                    _showAddConditionDialog(context, profileProvider),
                onDeleteItem: (item) =>
                    profileProvider.updateMedicalCondition(item, false),
                emptyText: 'No conditions added'),
            const SizedBox(height: 16),
            _buildEditableListSection(
                context: context,
                title: 'Allergies',
                icon: Icons.sick_outlined,
                iconColor: colorScheme.error,
                items: profileProvider.allergies,
                onAddItem: () =>
                    _showAddAllergyDialog(context, profileProvider),
                onDeleteItem: (item) => profileProvider.removeAllergy(item),
                emptyText: 'No allergies added'),
            const SizedBox(height: 16),
            _buildEditableListSection(
                context: context,
                title: 'Medications',
                icon: Icons.medication_outlined,
                iconColor: Colors.orange.shade700,
                items: profileProvider.medications
                    .map((m) => '${m.name} (${m.dosage})')
                    .toList(),
                onAddItem: () =>
                    _showAddMedicationDialog(context, profileProvider),
                onItemTap: (index) =>
                    _showEditMedicationDialog(context, profileProvider, index),
                onDeleteItem: null,
                emptyText: 'No medications added'),
            const SizedBox(height: 16),
            _buildEditableListSection(
                context: context,
                title: 'Emergency Contacts',
                icon: Icons.contact_emergency_outlined,
                iconColor: colorScheme.secondary,
                items: profileProvider.emergencyContacts
                    .map((c) => '${c.name}: ${c.phoneNumber}')
                    .toList(),
                onAddItem: () =>
                    _showAddEmergencyContactDialog(context, profileProvider),
                onDeleteItem: (item) {
                  int index = profileProvider.emergencyContacts
                      .indexWhere((c) => '${c.name}: ${c.phoneNumber}' == item);
                  if (index != -1) {
                    profileProvider.removeEmergencyContact(index);
                    _showSnackbar(
                        '${profileProvider.emergencyContacts[index].name} removed.',
                        success: false);
                  }
                },
                emptyText: 'No contacts added'),
            const SizedBox(height: 32),
            // Save Button
            ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label:
                    const Text('Save Profile', style: TextStyle(fontSize: 16)),
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary)),
          ]),
    );
  }

  Widget _buildEditSectionHeader(String title) {
    return Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Text(title,
            style: Theme.of(context).textTheme.titleLarge)); // Use titleLarge
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {bool isDropdown = false}) {
    return InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        suffixIcon: isDropdown ? const Icon(Icons.arrow_drop_down) : null);
  }

  String? _validateNumber(
      String? value, double min, double max, String fieldName) {
    if (value == null || value.isEmpty) return null;
    try {
      final number = double.parse(value);
      if (number <= min || number > max) return 'Invalid';
    } catch (e) {
      return 'Invalid';
    }
    return null;
  }

  Widget _buildEditableListSection(
      {required BuildContext context,
      required String title,
      required IconData icon,
      required List<String> items,
      required VoidCallback onAddItem,
      required Function(String item)? onDeleteItem,
      required String emptyText,
      Color? iconColor,
      Function(int index)? onItemTap}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(icon, color: iconColor ?? colorScheme.primary),
              const SizedBox(width: 12),
              Text(title, style: theme.textTheme.titleLarge)
            ]),
            IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: Colors.green.shade600),
                tooltip: 'Add $title',
                onPressed: onAddItem)
          ]),
          const Divider(height: 24),
          if (items.isNotEmpty)
            ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      trailing: onDeleteItem != null
                          ? IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: colorScheme.error),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Remove $item',
                              onPressed: () => onDeleteItem(item))
                          : null,
                      onTap: onItemTap != null ? () => onItemTap(index) : null);
                })
          else
            Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(emptyText,
                        style: const TextStyle(color: Colors.grey)))),
        ]),
      ),
    );
  }

  // --- Action Methods ---

  Future<void> _selectDate(
      BuildContext context, ProfileProvider profileProvider) async {
    if (!context.mounted) return;
    final currentYear = DateTime.now().year;
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime(currentYear - 30),
        firstDate: DateTime(currentYear - 120),
        lastDate: DateTime.now(),
        builder: (context, child) => Theme(
            data: Theme.of(context)
                .copyWith(colorScheme: Theme.of(context).colorScheme),
            child: child!));
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddAllergyDialog(
      BuildContext context, ProfileProvider profileProvider) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Add Allergy'),
                content: Form(
                    key: formKey,
                    child: TextFormField(
                        controller: controller,
                        decoration:
                            const InputDecoration(hintText: 'e.g., Peanuts'),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter allergy' : null,
                        onFieldSubmitted: (_) {
                          if (formKey.currentState!.validate()) {
                            _saveAllergyAndClose(
                                dialogContext, profileProvider, controller);
                          }
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          _saveAllergyAndClose(
                              dialogContext, profileProvider, controller);
                        }
                      },
                      child: const Text('Add'))
                ]));
  }

  void _saveAllergyAndClose(BuildContext dialogContext,
      ProfileProvider profileProvider, TextEditingController controller) {
    profileProvider.addAllergy(controller.text.trim());
    Navigator.pop(dialogContext);
    _showSnackbar('Allergy added', success: true);
  }

  void _showAddConditionDialog(
      BuildContext context, ProfileProvider profileProvider) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Add Medical Condition'),
                content: Form(
                    key: formKey,
                    child: TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                            hintText: 'e.g., Hypertension'),
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter condition' : null,
                        onFieldSubmitted: (_) {
                          if (formKey.currentState!.validate()) {
                            _addMedicalCondition(
                                profileProvider, controller.text);
                            Navigator.pop(dialogContext);
                          }
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          _addMedicalCondition(
                              profileProvider, controller.text);
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: const Text('Add'))
                ]));
  }

  void _addMedicalCondition(ProfileProvider profileProvider, String condition) {
    final trimmedCondition = condition.trim();
    if (trimmedCondition.isEmpty) {
      _showSnackbar('Please enter a condition.', success: false);
      return;
    }
    final index = profileProvider.medicalConditions.indexWhere(
        (c) => c.name.toLowerCase() == trimmedCondition.toLowerCase());
    if (index != -1 && !profileProvider.medicalConditions[index].selected) {
      profileProvider.updateMedicalCondition(
          profileProvider.medicalConditions[index].name, true);
      _showSnackbar(
          '${profileProvider.medicalConditions[index].name} marked as active.',
          success: true);
    } else if (index == -1) {
      profileProvider.addCustomMedicalCondition(
          MedicalCondition(name: trimmedCondition, selected: true));
      _showSnackbar('Condition "$trimmedCondition" added.', success: true);
    } else {
      _showSnackbar('Condition "$trimmedCondition" is already listed.',
          success: false);
    }
  }

  void _showAddMedicationDialog(
      BuildContext context, ProfileProvider profileProvider) {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Add Medication'),
                content: SingleChildScrollView(
                    child: Form(
                        key: formKey,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                  labelText: 'Medication Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medication_outlined)),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Name required'
                                  : null,
                              autofocus: true),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: dosageController,
                              decoration: const InputDecoration(
                                  labelText: 'Dosage (e.g., 10mg)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.science_outlined)),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Dosage required'
                                  : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: frequencyController,
                              decoration: const InputDecoration(
                                  labelText: 'Frequency (e.g., Twice daily)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.schedule_outlined)),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Frequency required'
                                  : null,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (formKey.currentState!.validate()) {
                                  _saveMedicationAndClose(
                                      dialogContext,
                                      profileProvider,
                                      nameController,
                                      dosageController,
                                      frequencyController);
                                }
                              })
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          _saveMedicationAndClose(
                              dialogContext,
                              profileProvider,
                              nameController,
                              dosageController,
                              frequencyController);
                        }
                      },
                      child: const Text('Add'))
                ]));
  }

  void _saveMedicationAndClose(
      BuildContext dialogContext,
      ProfileProvider profileProvider,
      TextEditingController name,
      TextEditingController dosage,
      TextEditingController frequency) {
    profileProvider.addMedication(Medication(
        name: name.text.trim(),
        dosage: dosage.text.trim(),
        frequency: frequency.text.trim()));
    Navigator.pop(dialogContext);
    _showSnackbar('Added ${name.text.trim()}', success: true);
  }

  void _showEditMedicationDialog(
      BuildContext context, ProfileProvider profileProvider, int index) {
    if (index < 0 || index >= profileProvider.medications.length) return;
    final medication = profileProvider.medications[index];
    final nameController = TextEditingController(text: medication.name);
    final dosageController = TextEditingController(text: medication.dosage);
    final frequencyController =
        TextEditingController(text: medication.frequency);
    final formKey = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: Text('Edit ${medication.name}'),
                content: SingleChildScrollView(
                    child: Form(
                        key: formKey,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                  labelText: 'Medication Name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medication_outlined)),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Name required'
                                  : null,
                              autofocus: true),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: dosageController,
                              decoration: const InputDecoration(
                                  labelText: 'Dosage',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.science_outlined)),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Dosage required'
                                  : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: frequencyController,
                              decoration: const InputDecoration(
                                  labelText: 'Frequency',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.schedule_outlined)),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Frequency required'
                                  : null,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (formKey.currentState!.validate()) {
                                  _updateMedicationAndClose(
                                      dialogContext,
                                      profileProvider,
                                      index,
                                      nameController,
                                      dosageController,
                                      frequencyController);
                                }
                              })
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          _updateMedicationAndClose(
                              dialogContext,
                              profileProvider,
                              index,
                              nameController,
                              dosageController,
                              frequencyController);
                        }
                      },
                      child: const Text('Save Changes'))
                ]));
  }

  void _updateMedicationAndClose(
      BuildContext dialogContext,
      ProfileProvider profileProvider,
      int index,
      TextEditingController name,
      TextEditingController dosage,
      TextEditingController frequency) {
    profileProvider.removeMedication(index);
    profileProvider.addMedication(Medication(
        name: name.text.trim(),
        dosage: dosage.text.trim(),
        frequency: frequency.text.trim()));
    Navigator.pop(dialogContext);
    _showSnackbar('Updated ${name.text.trim()}', success: true);
  }

  void _showAddEmergencyContactDialog(
      BuildContext context, ProfileProvider profileProvider) {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Add Emergency Contact'),
                content: Form(
                    key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Name required' : null,
                          textCapitalization: TextCapitalization.words,
                          autofocus: true),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: relationshipController,
                          decoration: const InputDecoration(
                              labelText: 'Relationship (Optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.people_outline)),
                          textCapitalization: TextCapitalization.sentences),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone_outlined)),
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Phone required'
                              : null,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (formKey.currentState!.validate()) {
                              _saveEmergencyContactAndClose(
                                  dialogContext,
                                  profileProvider,
                                  nameController,
                                  relationshipController,
                                  phoneController);
                            }
                          })
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          _saveEmergencyContactAndClose(
                              dialogContext,
                              profileProvider,
                              nameController,
                              relationshipController,
                              phoneController);
                        }
                      },
                      child: const Text('Add Contact'))
                ]));
  }

  void _saveEmergencyContactAndClose(
      BuildContext dialogContext,
      ProfileProvider profileProvider,
      TextEditingController name,
      TextEditingController relationship,
      TextEditingController phone) {
    profileProvider.addEmergencyContact(EmergencyContact(
        name: name.text.trim(),
        relationship: relationship.text.trim(),
        phoneNumber: phone.text.trim()));
    Navigator.pop(dialogContext);
    _showSnackbar('Added ${name.text.trim()} as contact', success: true);
  }

  void _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackbar('Please correct errors in the form.', success: false);
      return;
    }
    if (mounted) setState(() => _isSaving = true);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    double weight = double.tryParse(_weightController.text) ?? 0.0;
    double height = double.tryParse(_heightController.text) ?? 0.0;
    try {
      profileProvider.setName(_nameController.text.trim());
      profileProvider.setGender(_selectedGender);
      profileProvider.setBloodType(_selectedBloodType);
      profileProvider.setDateOfBirth(_selectedDate);
      profileProvider.setWeight(weight);
      profileProvider.setHeight(height);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });
        _showSnackbar('Profile saved!', success: true);
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackbar('Error saving profile.', success: false);
      }
    }
  }

  void _confirmClearProfile() {
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Clear Profile Data?'),
                content: const Text(
                    'This permanently deletes all profile information and cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        try {
                          await Provider.of<ProfileProvider>(context,
                                  listen: false)
                              .clearProfile();
                          if (mounted) {
                            setState(() {
                              _initializeStateFromProvider();
                              _isEditing = false;
                            });
                            _showSnackbar('Profile data cleared.',
                                success: true);
                          }
                        } catch (e) {
                          debugPrint("Error clearing profile: $e");
                          if (mounted) {
                            _showSnackbar('Failed to clear profile.',
                                success: false);
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Clear Data'))
                ]));
  }
} // End of _ProfilePageState
