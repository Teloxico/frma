// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Manages the application's theme mode (light, dark, system)
class ThemeProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  ThemeMode _themeMode = ThemeMode.system;
  static const String _keyThemeMode =
      'theme_mode'; // Key for storing theme mode

  ThemeProvider(this.prefs) {
    _loadThemeMode(); // Load saved theme on initialization
  }

  // Getter for the current theme mode
  ThemeMode get themeMode => _themeMode;

  // Getter to check if dark mode is effectively active (considers system setting)
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // If system is selected, check the actual platform brightness
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    // Otherwise, just check if dark mode is explicitly selected
    return _themeMode == ThemeMode.dark;
  }

  // Loads the saved theme mode from SharedPreferences
  void _loadThemeMode() {
    try {
      final themeModeIndex = prefs.getInt(_keyThemeMode) ??
          ThemeMode.system.index; // Default to system
      if (themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeModeIndex];
      }
      // No need to notifyListeners here as it's called during construction
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  // Sets the theme mode and saves it to SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      try {
        await prefs.setInt(_keyThemeMode, mode.index);
      } catch (e) {
        debugPrint('Error saving theme mode: $e');
      }
      notifyListeners(); // Notify listeners about the change
    }
  }

  // Toggles the theme between light and dark (or based on system if system is set)
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : (_themeMode == ThemeMode.dark
            ? ThemeMode.light
            : (isDarkMode
                ? ThemeMode.light
                : ThemeMode
                    .dark)); // Choose opposite of current effective mode if system
    await setThemeMode(newMode);
  }
}
