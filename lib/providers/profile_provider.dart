// lib/providers/profile_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// --- Data Models ---

class MedicalCondition {
  final String name;
  bool selected;

  MedicalCondition({required this.name, this.selected = false});

  Map<String, dynamic> toJson() => {'name': name, 'selected': selected};
  factory MedicalCondition.fromJson(Map<String, dynamic> json) =>
      MedicalCondition(
          name: json['name'] ?? 'Unknown Condition',
          selected: json['selected'] ?? false);
}

class Medication {
  final String name;
  final String dosage;
  final String frequency;

  Medication(
      {required this.name, required this.dosage, required this.frequency});

  Map<String, dynamic> toJson() =>
      {'name': name, 'dosage': dosage, 'frequency': frequency};
  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
      name: json['name'] ?? 'Unknown Medication',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '');
}

class EmergencyContact {
  final String name;
  final String relationship;
  final String phoneNumber;

  EmergencyContact(
      {required this.name,
      required this.relationship,
      required this.phoneNumber});

  Map<String, dynamic> toJson() =>
      {'name': name, 'relationship': relationship, 'phoneNumber': phoneNumber};
  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
          name: json['name'] ?? 'Unknown Contact',
          relationship: json['relationship'] ?? '',
          phoneNumber: json['phoneNumber'] ?? '');
}

// --- Profile Provider ---

class ProfileProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  // State variables
  String _name = '';
  DateTime? _dateOfBirth;
  String _gender = '';
  double _weight = 0.0;
  double _height = 0.0;
  String _bloodType = '';
  List<MedicalCondition> _medicalConditions = [];
  List<String> _allergies = [];
  List<Medication> _medications = [];
  List<EmergencyContact> _emergencyContacts = [];

  // Constants
  static const String _keyPrefix = 'profile_';
  static const List<String> _defaultConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Allergies',
    'Arthritis',
    'Cancer',
    'COPD',
    'Depression',
    'Epilepsy',
    'Glaucoma',
    'HIV/AIDS',
    'Kidney Disease',
    'Liver Disease',
    'Migraine',
    'Multiple Sclerosis',
    'Osteoporosis',
    'Parkinson\'s Disease',
    'Thyroid Disorder'
  ];
  static const String _keyName = '${_keyPrefix}name';
  static const String _keyDob = '${_keyPrefix}dob';
  static const String _keyGender = '${_keyPrefix}gender';
  static const String _keyWeight = '${_keyPrefix}weight';
  static const String _keyHeight = '${_keyPrefix}height';
  static const String _keyBloodType = '${_keyPrefix}blood_type';
  static const String _keyMedicalConditions = '${_keyPrefix}medical_conditions';
  static const String _keyAllergies = '${_keyPrefix}allergies';
  static const String _keyMedications = '${_keyPrefix}medications';
  static const String _keyEmergencyContacts = '${_keyPrefix}emergency_contacts';

  ProfileProvider(this.prefs) {
    _loadProfile();
  }

  // --- Getters ---
  String get name => _name;
  DateTime? get dateOfBirth => _dateOfBirth;
  String get gender => _gender;
  double get weight => _weight;
  double get height => _height;
  String get bloodType => _bloodType;
  List<MedicalCondition> get medicalConditions =>
      List.unmodifiable(_medicalConditions);
  List<String> get allergies => List.unmodifiable(_allergies);
  List<Medication> get medications => List.unmodifiable(_medications);
  List<EmergencyContact> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);

  // --- Computed Getters ---
  int? get age {
    if (_dateOfBirth == null) return null;
    final today = DateTime.now();
    int age = today.year - _dateOfBirth!.year;
    if (today.month < _dateOfBirth!.month ||
        (today.month == _dateOfBirth!.month && today.day < _dateOfBirth!.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  double? get bmi {
    if (_weight <= 0 || _height <= 0) return null;
    final heightInMeters = _height / 100;
    if (heightInMeters == 0) return null;
    return _weight / (heightInMeters * heightInMeters);
  }

  String get bmiCategory {
    final bmiValue = bmi;
    if (bmiValue == null) return 'Unknown';
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  // --- Internal Methods ---

  void _loadProfile() {
    try {
      _name = prefs.getString(_keyName) ?? '';
      final dobStr = prefs.getString(_keyDob);
      _dateOfBirth = dobStr != null ? DateTime.tryParse(dobStr) : null;
      _gender = prefs.getString(_keyGender) ?? '';
      _weight = prefs.getDouble(_keyWeight) ?? 0.0;
      _height = prefs.getDouble(_keyHeight) ?? 0.0;
      _bloodType = prefs.getString(_keyBloodType) ?? '';

      _medicalConditions =
          _loadList(_keyMedicalConditions, MedicalCondition.fromJson) ??
              _getDefaultMedicalConditions();
      _allergies = prefs.getStringList(_keyAllergies) ?? [];
      _medications = _loadList(_keyMedications, Medication.fromJson) ?? [];
      _emergencyContacts =
          _loadList(_keyEmergencyContacts, EmergencyContact.fromJson) ?? [];
    } catch (e) {
      debugPrint('Error loading profile: $e');
      // Reset to defaults if loading fails critically
      _name = '';
      _dateOfBirth = null;
      _gender = '';
      _weight = 0.0;
      _height = 0.0;
      _bloodType = '';
      _medicalConditions =
          _getDefaultMedicalConditions(); // Use the correct helper
      _allergies = [];
      _medications = [];
      _emergencyContacts = [];
    }
  }

  List<T>? _loadList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final jsonString = prefs.getString(key);
    if (jsonString != null) {
      try {
        final dynamic decodedData = jsonDecode(jsonString);
        if (decodedData is List) {
          return decodedData
              .map((item) => fromJson(item as Map<String, dynamic>))
              .toList();
        } else {
          debugPrint(
              'Error decoding list for key $key: Expected List but got ${decodedData.runtimeType}');
          prefs.remove(key);
          return null;
        }
      } catch (e) {
        debugPrint('Error decoding or processing list for key $key: $e');
        prefs.remove(key);
        return null;
      }
    }
    return null;
  }

  // Returns the default list of medical conditions
  List<MedicalCondition> _getDefaultMedicalConditions() {
    return _defaultConditions
        .map((name) => MedicalCondition(name: name))
        .toList();
  }

  // Removed the unused _initializeDefaultMedicalConditions method

  Future<void> _saveProfile() async {
    try {
      await prefs.setString(_keyName, _name);
      if (_dateOfBirth != null) {
        await prefs.setString(_keyDob, _dateOfBirth!.toIso8601String());
      } else {
        await prefs.remove(_keyDob);
      }
      await prefs.setString(_keyGender, _gender);
      await prefs.setDouble(_keyWeight, _weight);
      await prefs.setDouble(_keyHeight, _height);
      await prefs.setString(_keyBloodType, _bloodType);

      await _saveList(_keyMedicalConditions, _medicalConditions);
      await prefs.setStringList(_keyAllergies, _allergies);
      await _saveList(_keyMedications, _medications);
      await _saveList(_keyEmergencyContacts, _emergencyContacts);
    } catch (e) {
      debugPrint('Error saving profile: $e');
      rethrow;
    }
  }

  Future<void> _saveList<T>(String key, List<T> list) async {
    List<Map<String, dynamic>> jsonList = list
        .map((item) => (item as dynamic).toJson() as Map<String, dynamic>)
        .toList();
    await prefs.setString(key, jsonEncode(jsonList));
  }

  // --- Public Methods to Update Profile Data ---

  Future<void> _updateAndSave(VoidCallback updateAction) async {
    updateAction();
    await _saveProfile();
    notifyListeners();
  }

  void setName(String value) => _updateAndSave(() => _name = value);
  void setDateOfBirth(DateTime? value) =>
      _updateAndSave(() => _dateOfBirth = value);
  void setGender(String value) => _updateAndSave(() => _gender = value);
  void setWeight(double value) =>
      _updateAndSave(() => _weight = value >= 0 ? value : 0);
  void setHeight(double value) =>
      _updateAndSave(() => _height = value >= 0 ? value : 0);
  void setBloodType(String value) => _updateAndSave(() => _bloodType = value);

  void updateMedicalCondition(String name, bool selected) {
    _updateAndSave(() {
      final index = _medicalConditions.indexWhere((c) => c.name == name);
      if (index != -1) {
        _medicalConditions[index].selected = selected;
      }
    });
  }

  void addCustomMedicalCondition(MedicalCondition condition) {
    _updateAndSave(() {
      final index = _medicalConditions.indexWhere(
          (c) => c.name.toLowerCase() == condition.name.toLowerCase());
      if (index != -1) {
        _medicalConditions[index].selected = condition.selected;
      } else {
        _medicalConditions.add(condition);
      }
    });
  }

  void removeMedicalCondition(String name) {
    _updateAndSave(() {
      _medicalConditions.removeWhere((c) => c.name == name);
    });
  }

  void addAllergy(String allergy) {
    final trimmedAllergy = allergy.trim();
    if (trimmedAllergy.isNotEmpty && !_allergies.contains(trimmedAllergy)) {
      _updateAndSave(() => _allergies.add(trimmedAllergy));
    }
  }

  void removeAllergy(String allergy) {
    if (_allergies.contains(allergy)) {
      _updateAndSave(() => _allergies.remove(allergy));
    }
  }

  void addMedication(Medication medication) {
    _updateAndSave(() => _medications.add(medication));
  }

  void removeMedication(int index) {
    if (index >= 0 && index < _medications.length) {
      _updateAndSave(() => _medications.removeAt(index));
    }
  }

  void addEmergencyContact(EmergencyContact contact) {
    _updateAndSave(() => _emergencyContacts.add(contact));
  }

  void removeEmergencyContact(int index) {
    if (index >= 0 && index < _emergencyContacts.length) {
      _updateAndSave(() => _emergencyContacts.removeAt(index));
    }
  }

  Future<void> clearProfile() async {
    _name = '';
    _dateOfBirth = null;
    _gender = '';
    _weight = 0.0;
    _height = 0.0;
    _bloodType = '';
    _medicalConditions = _getDefaultMedicalConditions();
    _allergies = [];
    _medications = [];
    _emergencyContacts = [];

    // Clear corresponding keys from SharedPreferences
    await prefs.remove(_keyName);
    await prefs.remove(_keyDob);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyWeight);
    await prefs.remove(_keyHeight);
    await prefs.remove(_keyBloodType);
    await prefs.remove(_keyMedicalConditions);
    await prefs.remove(_keyAllergies);
    await prefs.remove(_keyMedications);
    await prefs.remove(_keyEmergencyContacts);

    notifyListeners();
  }
}
