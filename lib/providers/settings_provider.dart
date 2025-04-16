// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_mode.dart';
import '../services/api_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  final ApiService _apiService = ApiService();

  // Define the default URL as a constant within this provider
  static const String _defaultLocalServerUrl = "http://localhost:8000";

  // --- State Variables ---
  Color _primaryColor = Colors.blue;
  Color _userBubbleColor = Colors.blue.shade100;
  Color _botBubbleColor = Colors.grey.shade200;
  double _fontSize = 16.0;
  bool _highContrast = false;
  bool _enableNotifications = true;
  bool _enableSoundEffects = true;
  bool _saveConversationHistory = true;
  ApiMode _apiMode = ApiMode.localServer;
  String? _apiKeyStatus;
  String? _endpointId;
  // Initialize with the constant default URL
  String _localServerUrl = _defaultLocalServerUrl;

  // --- Keys for SharedPreferences ---
  static const String _keyPrefix = 'settings_';
  static const String _keyPrimaryColor = '${_keyPrefix}primary_color';
  static const String _keyUserBubbleColor = '${_keyPrefix}user_bubble_color';
  static const String _keyBotBubbleColor = '${_keyPrefix}bot_bubble_color';
  static const String _keyFontSize = '${_keyPrefix}font_size';
  static const String _keyHighContrast = '${_keyPrefix}high_contrast';
  static const String _keyEnableNotifications =
      '${_keyPrefix}enable_notifications';
  static const String _keyEnableSoundEffects =
      '${_keyPrefix}enable_sound_effects';
  static const String _keySaveHistory =
      '${_keyPrefix}save_conversation_history';
  static const String _keyApiMode = 'use_local_server';
  static const String _keyEndpointId = 'runpod_endpoint_id';
  static const String _keyLocalServerUrl = 'local_server_url';

  SettingsProvider(this.prefs) {
    _loadSettings();
    _checkApiKeyStatus();
  }

  // --- Getters ---
  Color get primaryColor => _primaryColor;
  Color get userBubbleColor => _userBubbleColor;
  Color get botBubbleColor => _botBubbleColor;
  double get fontSize => _fontSize;
  bool get highContrast => _highContrast;
  bool get enableNotifications => _enableNotifications;
  bool get enableSoundEffects => _enableSoundEffects;
  bool get saveConversationHistory => _saveConversationHistory;
  ApiMode get apiMode => _apiMode;
  String get apiKeyStatus => _apiKeyStatus ?? 'Not configured';
  String? get endpointId => _endpointId;
  String get localServerUrl => _localServerUrl;

  // --- Load All Settings ---
  Future<void> _loadSettings() async {
    try {
      _primaryColor =
          Color(prefs.getInt(_keyPrimaryColor) ?? Colors.blue.value);
      _userBubbleColor = Color(
          prefs.getInt(_keyUserBubbleColor) ?? Colors.blue.shade100.value);
      _botBubbleColor =
          Color(prefs.getInt(_keyBotBubbleColor) ?? Colors.grey.shade200.value);
      _fontSize = prefs.getDouble(_keyFontSize) ?? _fontSize;
      _highContrast = prefs.getBool(_keyHighContrast) ?? _highContrast;
      _enableNotifications =
          prefs.getBool(_keyEnableNotifications) ?? _enableNotifications;
      _enableSoundEffects =
          prefs.getBool(_keyEnableSoundEffects) ?? _enableSoundEffects;
      _saveConversationHistory =
          prefs.getBool(_keySaveHistory) ?? _saveConversationHistory;
      _endpointId = prefs.getString(_keyEndpointId);
      // Use the class constant as the default value when loading
      _localServerUrl =
          prefs.getString(_keyLocalServerUrl) ?? _defaultLocalServerUrl;
      _apiMode = (prefs.getBool(_keyApiMode) ?? true)
          ? ApiMode.localServer
          : ApiMode.runPod;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // --- API Key Status ---
  Future<void> _checkApiKeyStatus() async {
    try {
      final isSet = await _apiService.isApiKeySet();
      _apiKeyStatus =
          isSet ? _apiService.getApiKeyStatusMessage() : 'Not configured';
    } catch (e) {
      _apiKeyStatus = 'Error checking API key';
    }
    notifyListeners();
  }

  // --- Setters for API Configuration ---
  Future<void> setApiKey(String apiKey) async {
    try {
      await _apiService.saveApiKey(apiKey);
      await _checkApiKeyStatus();
    } catch (e) {
      debugPrint('Error saving API key: $e');
      rethrow;
    }
  }

  Future<void> setLocalServerUrl(String url) async {
    try {
      _localServerUrl = url;
      await _apiService.saveLocalServerUrl(url);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving local server URL: $e');
      rethrow;
    }
  }

  Future<void> setEndpointId(String endpointId) async {
    try {
      _endpointId = endpointId;
      await _apiService.saveEndpointId(endpointId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving endpoint ID: $e');
      rethrow;
    }
  }

  Future<void> setApiMode(ApiMode mode) async {
    if (_apiMode == mode) return;
    try {
      _apiMode = mode;
      await _apiService.setUseLocalServer(mode == ApiMode.localServer);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting API mode: $e');
      rethrow;
    }
  }

  Future<void> clearApiKey() async {
    try {
      await _apiService.clearApiKey();
      await _checkApiKeyStatus();
    } catch (e) {
      debugPrint('Error clearing API key: $e');
      rethrow;
    }
  }

  // --- Setters for UI/Feature Settings ---
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor == color) return;
    _primaryColor = color;
    await prefs.setInt(_keyPrimaryColor, color.value);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    await prefs.setDouble(_keyFontSize, size);
    notifyListeners();
  }

  // --- Toggles for Boolean Settings ---
  Future<void> _toggleBoolSetting(String key, bool currentValue) async {
    final newValue = !currentValue;
    await prefs.setBool(key, newValue);
    switch (key) {
      case _keyHighContrast:
        _highContrast = newValue;
        break;
      case _keyEnableNotifications:
        _enableNotifications = newValue;
        break;
      case _keyEnableSoundEffects:
        _enableSoundEffects = newValue;
        break;
      case _keySaveHistory:
        _saveConversationHistory = newValue;
        break;
    }
    notifyListeners();
  }

  Future<void> toggleHighContrast() =>
      _toggleBoolSetting(_keyHighContrast, _highContrast);
  Future<void> toggleNotifications() =>
      _toggleBoolSetting(_keyEnableNotifications, _enableNotifications);
  Future<void> toggleSoundEffects() =>
      _toggleBoolSetting(_keyEnableSoundEffects, _enableSoundEffects);
  Future<void> toggleSaveConversationHistory() =>
      _toggleBoolSetting(_keySaveHistory, _saveConversationHistory);

  // --- API Connection Test ---
  Future<bool> testConnection() async {
    try {
      return await _apiService.verifyEndpoint();
    } catch (e) {
      debugPrint('Error testing connection: $e');
      return false;
    }
  }

  // --- Reset All Settings to Defaults ---
  Future<void> resetToDefaults() async {
    final defaultPrimaryColor = Colors.blue;
    final defaultUserBubbleColor = Colors.blue.shade100;
    final defaultBotBubbleColor = Colors.grey.shade200;
    const defaultFontSize = 16.0;
    const defaultHighContrast = false;
    const defaultEnableNotifications = true;
    const defaultEnableSoundEffects = true;
    const defaultSaveHistory = true;
    const defaultApiMode = ApiMode.localServer;
    // Use the class constant for the default URL
    const defaultLocalUrl = _defaultLocalServerUrl;

    _primaryColor = defaultPrimaryColor;
    _userBubbleColor = defaultUserBubbleColor;
    _botBubbleColor = defaultBotBubbleColor;
    _fontSize = defaultFontSize;
    _highContrast = defaultHighContrast;
    _enableNotifications = defaultEnableNotifications;
    _enableSoundEffects = defaultEnableSoundEffects;
    _saveConversationHistory = defaultSaveHistory;
    _apiMode = defaultApiMode;
    _localServerUrl = defaultLocalUrl;
    _endpointId = null;

    await prefs.setInt(_keyPrimaryColor, _primaryColor.value);
    await prefs.setInt(_keyUserBubbleColor, _userBubbleColor.value);
    await prefs.setInt(_keyBotBubbleColor, _botBubbleColor.value);
    await prefs.setDouble(_keyFontSize, _fontSize);
    await prefs.setBool(_keyHighContrast, _highContrast);
    await prefs.setBool(_keyEnableNotifications, _enableNotifications);
    await prefs.setBool(_keyEnableSoundEffects, _enableSoundEffects);
    await prefs.setBool(_keySaveHistory, _saveConversationHistory);

    await _apiService.setUseLocalServer(true);
    await _apiService.saveLocalServerUrl(defaultLocalUrl);
    await prefs.remove(_keyEndpointId);

    await _checkApiKeyStatus();

    notifyListeners();
  }
}
