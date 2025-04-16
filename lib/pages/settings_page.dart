// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_mode.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/drawer_menu.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isTesting = false;
  ApiMode _selectedApiMode = ApiMode.localServer;
  final _localServerUrlController = TextEditingController();
  final _runpodEndpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeControllers();
      }
    });
  }

  @override
  void dispose() {
    _localServerUrlController.dispose();
    _runpodEndpointController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    // Use setState only if the widget is still mounted
    if (mounted) {
      setState(() {
        _selectedApiMode = settingsProvider.apiMode;
        _localServerUrlController.text = settingsProvider.localServerUrl;
        _runpodEndpointController.text = settingsProvider.endpointId ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final colorScheme =
        Theme.of(context).colorScheme; // Get color scheme for theme colors

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 1.0, // Use subtle elevation
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined), // Use outlined icon
            onPressed: () => _resetSettings(context, settingsProvider),
            tooltip: 'Reset Appearance & Notification Settings',
          ),
        ],
      ),
      drawer: const DrawerMenu(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- API Configuration Section ---
          _buildSectionCard(
            title: 'API Configuration',
            icon: Icons.cloud_queue,
            children: [
              ListTile(
                leading:
                    Icon(_selectedApiMode.icon, color: colorScheme.primary),
                title: const Text('Connection Mode'),
                subtitle: Text(_selectedApiMode.description),
                trailing: const Icon(Icons.edit_outlined,
                    size: 20), // Use outlined icon
                onTap: () => _showApiModeDialog(context, settingsProvider),
              ),
              if (_selectedApiMode == ApiMode.localServer)
                _buildLocalServerSettings(settingsProvider)
              else if (_selectedApiMode == ApiMode.runPod)
                _buildRunPodSettings(settingsProvider),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18, // Slightly smaller indicator
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.network_check_outlined,
                            size: 20), // Use outlined icon
                    label: const Text('Test Connection'),
                    onPressed: _isTesting
                        ? null
                        : () => _testApiConnection(settingsProvider),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            colorScheme.secondary, // Use secondary theme color
                        foregroundColor: colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16.0, 8.0, 16.0, 16.0), // Add bottom padding
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        _saveApiSettings(context, settingsProvider),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            colorScheme.primary, // Use primary theme color
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Save API Settings'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- Appearance Section ---
          _buildSectionCard(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Theme Mode'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeProvider.themeMode,
                  onChanged: (ThemeMode? newMode) {
                    if (newMode != null) {
                      themeProvider.setThemeMode(newMode);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('System Default')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(
                        value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  underline:
                      Container(), // Remove default underline for cleaner look
                ),
              ),
              ListTile(
                leading: const Icon(Icons.color_lens_outlined),
                title: const Text('Primary Color'),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        settingsProvider.primaryColor, // Display selected color
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                onTap: () => _showColorPicker(context, settingsProvider),
              ),
              ListTile(
                leading: const Icon(Icons.format_size_outlined),
                title: const Text('Font Size'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Slider(
                    value: settingsProvider.fontSize,
                    min: 12.0, max: 24.0, divisions: 6,
                    label: '${settingsProvider.fontSize.round()}',
                    onChanged: (value) => settingsProvider.setFontSize(value),
                    // Use theme colors for slider
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.primary.withOpacity(0.3),
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.contrast_outlined),
                title: const Text('High Contrast Mode'),
                subtitle: const Text(
                    'Increases UI contrast (requires app restart)'), // Clarify restart need
                value: settingsProvider.highContrast,
                onChanged: (_) => settingsProvider.toggleHighContrast(),
                activeColor: colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- Notifications Section ---
          _buildSectionCard(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive health & medication reminders'),
                value: settingsProvider.enableNotifications,
                onChanged: (_) => settingsProvider.toggleNotifications(),
                activeColor: colorScheme.primary,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Sound Effects'),
                subtitle: const Text('Play sounds for actions & notifications'),
                value: settingsProvider.enableSoundEffects,
                onChanged: (_) => settingsProvider.toggleSoundEffects(),
                activeColor: colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- Privacy & Data Section ---
          _buildSectionCard(
            title: 'Privacy & Data',
            icon: Icons.privacy_tip_outlined,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.history_outlined),
                title: const Text('Save Conversation History'),
                subtitle: const Text('Keep chat messages locally'),
                value: settingsProvider.saveConversationHistory,
                onChanged: (_) =>
                    settingsProvider.toggleSaveConversationHistory(),
                activeColor: colorScheme.primary,
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Export Your Data'),
                subtitle: const Text('Copy profile & settings to clipboard'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportData(context),
              ),
              const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Clear All App Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          colorScheme.error, // Use theme error color
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => _showClearDataDialog(context),
                  ),
                ),
              ),
            ],
          ),

          // --- App Info Footer ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Health Assistant v1.0.0', // TODO: Make dynamic if possible
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets for Build Method ---

  Widget _buildLocalServerSettings(SettingsProvider settingsProvider) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Adjusted padding
      child: TextField(
        controller: _localServerUrlController,
        decoration: const InputDecoration(
          labelText: 'Local Server URL',
          hintText: 'e.g., http://192.168.1.10:8000', // More realistic hint
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.link_outlined),
        ),
        keyboardType: TextInputType.url,
      ),
    );
  }

  Widget _buildRunPodSettings(SettingsProvider settingsProvider) {
    return Padding(
      // Wrap in padding
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('RunPod API Key'),
            subtitle: Text(settingsProvider.apiKeyStatus),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () => _showApiKeyDialog(context, settingsProvider),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0), // Adjust padding
            child: TextField(
              controller: _runpodEndpointController,
              decoration: const InputDecoration(
                labelText: 'RunPod Endpoint ID',
                hintText: 'Enter your RunPod endpoint ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary), // Use theme color
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- Dialogs and Action Methods ---

  void _showApiModeDialog(
      BuildContext context, SettingsProvider settingsProvider) {
    final initialMode = _selectedApiMode;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Connection Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildApiModeOption(
              context: dialogContext,
              mode: ApiMode.localServer,
              isSelected: _selectedApiMode == ApiMode.localServer,
              onTap: () {
                if (mounted) {
                  setState(() => _selectedApiMode = ApiMode.localServer);
                }
                Navigator.pop(dialogContext);
              },
            ),
            const SizedBox(height: 12),
            _buildApiModeOption(
              context: dialogContext,
              mode: ApiMode.runPod,
              isSelected: _selectedApiMode == ApiMode.runPod,
              onTap: () {
                if (mounted) {
                  setState(() => _selectedApiMode = ApiMode.runPod);
                }
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                setState(() =>
                    _selectedApiMode = initialMode); // Revert if cancelled
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildApiModeOption({
    required BuildContext context,
    required ApiMode mode,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withOpacity(0.5), // Use theme colors
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, // Slightly less bold
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary)
            else
              Icon(Icons.radio_button_unchecked, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }

  Future<void> _saveApiSettings(
      BuildContext context, SettingsProvider settingsProvider) async {
    HapticFeedback.mediumImpact();
    final String localUrl = _localServerUrlController.text.trim();
    final String endpointId = _runpodEndpointController.text.trim();
    final ApiMode modeToSave = _selectedApiMode;

    if (modeToSave == ApiMode.localServer &&
        !localUrl.startsWith(RegExp(r'https?://'))) {
      _showErrorSnackbar(context, 'Invalid Local Server URL format.');
      return;
    }
    if (modeToSave == ApiMode.runPod && endpointId.isEmpty) {
      _showErrorSnackbar(context, 'RunPod Endpoint ID cannot be empty.');
      return;
    }

    try {
      // Persist settings through the provider
      await settingsProvider.setApiMode(modeToSave);
      if (modeToSave == ApiMode.localServer) {
        await settingsProvider.setLocalServerUrl(localUrl);
      } else {
        await settingsProvider.setEndpointId(endpointId);
      }
      _showSuccessSnackbar(context, 'API settings saved!');
    } catch (e) {
      debugPrint("Error saving API settings: $e");
      _showErrorSnackbar(context, 'Error saving settings.');
    }
  }

  Future<void> _testApiConnection(SettingsProvider settingsProvider) async {
    if (mounted) setState(() => _isTesting = true);
    final currentMode = _selectedApiMode;
    final String tempLocalUrl = _localServerUrlController.text.trim();
    final String tempEndpointId = _runpodEndpointController.text.trim();
    bool isConnected = false;

    final originalMode = settingsProvider.apiMode;
    final originalUrl = settingsProvider.localServerUrl;
    final originalEndpoint = settingsProvider.endpointId;

    try {
      // Temporarily apply UI settings to the provider for the test
      await settingsProvider.setApiMode(currentMode);
      if (currentMode == ApiMode.localServer) {
        await settingsProvider.setLocalServerUrl(tempLocalUrl);
      } else {
        await settingsProvider.setEndpointId(tempEndpointId);
      }

      isConnected = await settingsProvider.testConnection();

      _showInfoSnackbar(
          context,
          isConnected ? 'Connection successful!' : 'Connection failed.',
          isConnected);
    } catch (e) {
      debugPrint("Error testing connection: $e");
      _showErrorSnackbar(context, 'Error during connection test.');
    } finally {
      // Restore original provider settings
      try {
        await settingsProvider.setApiMode(originalMode);
        await settingsProvider.setLocalServerUrl(originalUrl);
        await settingsProvider.setEndpointId(originalEndpoint ?? '');
      } catch (restoreError) {
        debugPrint(
            "Error restoring provider settings after test: $restoreError");
      }
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  void _showApiKeyDialog(
      BuildContext context, SettingsProvider settingsProvider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set RunPod API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'Paste your RunPod API key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key_outlined),
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (settingsProvider.apiKeyStatus != 'Not configured')
            TextButton(
              onPressed: () async {
                try {
                  await settingsProvider.clearApiKey();
                  Navigator.pop(dialogContext); // Close the dialog first
                  _showSuccessSnackbar(context, 'API Key cleared.');
                } catch (e) {
                  debugPrint("Error clearing API key: $e");
                  _showErrorSnackbar(context, 'Failed to clear API Key.');
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Clear Key'),
            ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  await settingsProvider.setApiKey(controller.text.trim());
                  Navigator.pop(dialogContext); // Close the dialog first
                  _showSuccessSnackbar(context, 'API Key saved.');
                } catch (e) {
                  debugPrint("Error saving API key: $e");
                  _showErrorSnackbar(context, 'Failed to save API Key.');
                }
              } else {
                _showErrorSnackbar(dialogContext,
                    'API Key cannot be empty.'); // Show error within dialog
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(
      BuildContext context, SettingsProvider settingsProvider) {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.lime,
      Colors.brown,
      Colors.grey.shade600,
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Primary Color'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: colors
                .map((color) => GestureDetector(
                      onTap: () {
                        settingsProvider.setPrimaryColor(color);
                        Navigator.pop(dialogContext);
                      },
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == settingsProvider.primaryColor
                                ? Theme.of(context)
                                    .colorScheme
                                    .outline // Use outline color for border
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 3,
                                spreadRadius: 1),
                          ],
                        ),
                        child: color == settingsProvider.primaryColor
                            ? Icon(Icons.check,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                size: 20) // Adjust check color
                            : null,
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _resetSettings(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
            'Reset Appearance and Notification settings to defaults? API settings remain unchanged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Only reset relevant settings, not API ones
                await settingsProvider
                    .resetToDefaults(); // This now correctly excludes API keys etc.
                if (mounted) {
                  Navigator.pop(dialogContext);
                  _initializeControllers(); // Refresh controllers
                  _showSuccessSnackbar(context, 'Settings reset to defaults.');
                }
              } catch (e) {
                debugPrint("Error resetting settings: $e");
                if (mounted) {
                  _showErrorSnackbar(context, 'Failed to reset settings.');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All App Data?'),
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error), // Add warning icon
        content: const Text(
            'WARNING: Permanently delete profile, settings, history, etc.? This cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Add a small delay for user to reconsider
              await Future.delayed(const Duration(milliseconds: 300));
              try {
                await _clearAllData(context);
                // Check mount status *before* popping potentially invalid context
                if (mounted) {
                  Navigator.pop(dialogContext); // Close this dialog
                  _showSuccessSnackbar(context, 'All app data cleared.');
                }
              } catch (e) {
                debugPrint("Error clearing data: $e");
                // Check mount status before showing snackbar
                if (mounted) {
                  _showErrorSnackbar(context, 'Failed to clear app data.');
                }
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('CLEAR ALL DATA'),
          ),
        ],
      ),
    );
  }

  // Performs the actual data clearing
  Future<void> _clearAllData(BuildContext context) async {
    // Ensure context is still valid before accessing providers
    if (!context.mounted) return;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();
    profileProvider.clearProfile();
    // Resetting settings provider also clears relevant prefs again, but ensures state is default
    await settingsProvider.resetToDefaults();
    try {
      // Also clear the securely stored API key
      await settingsProvider.clearApiKey();
    } catch (_) {
      debugPrint("Note: Could not clear API key during full data clear.");
    }

    // Re-initialize controllers only if widget is still mounted
    if (mounted) {
      _initializeControllers();
    }
  }

  Future<void> _exportData(BuildContext context) async {
    if (!context.mounted) return; // Check mounted before async gap
    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      final Map<String, dynamic> exportData = {
        'profile': {
          'name': profileProvider.name,
          'dateOfBirth': profileProvider.dateOfBirth?.toIso8601String(),
          'gender': profileProvider.gender,
          'weight': profileProvider.weight,
          'height': profileProvider.height,
          'bloodType': profileProvider.bloodType,
          'medicalConditions': profileProvider.medicalConditions
              .where((c) => c.selected)
              .map((c) => c.name)
              .toList(),
          'allergies': profileProvider.allergies,
          'medications':
              profileProvider.medications.map((m) => m.toJson()).toList(),
          'emergencyContacts':
              profileProvider.emergencyContacts.map((c) => c.toJson()).toList(),
        },
        'settings': {
          'primaryColorValue':
              settingsProvider.primaryColor.value, // Save int value
          'fontSize': settingsProvider.fontSize,
          'highContrast': settingsProvider.highContrast,
          'enableNotifications': settingsProvider.enableNotifications,
          'enableSoundEffects': settingsProvider.enableSoundEffects,
          'saveConversationHistory': settingsProvider.saveConversationHistory,
          'apiMode': settingsProvider.apiMode.name,
          'localServerUrl': settingsProvider.localServerUrl,
          'endpointId': settingsProvider.endpointId,
        },
        'exportMetadata': {
          'exportedAt': DateTime.now().toIso8601String(),
          'appVersion': '1.0.0',
        }
      };

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final String jsonData = jsonEncoder.convert(exportData);

      await Clipboard.setData(ClipboardData(text: jsonData));

      _showSuccessSnackbar(context, 'Data copied to clipboard.'); // Use helper
    } catch (e) {
      debugPrint("Error exporting data: $e");
      _showErrorSnackbar(context, 'Error exporting data.'); // Use helper
    }
  }

  // --- Snackbar Helpers (Ensures mounted check) ---
  void _showSuccessSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade600), // Slightly darker green
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor:
              Theme.of(context).colorScheme.error), // Use theme error color
    );
  }

  void _showInfoSnackbar(BuildContext context, String message, bool success) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: success
              ? Colors.green.shade600
              : Colors.orange.shade700), // Use theme colors
    );
  }
}
