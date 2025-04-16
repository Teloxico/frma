// lib/services/medical_knowledge_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// Model for emergency condition data loaded from JSON
class EmergencyCondition {
  final String id;
  final String title;
  final String description;
  final String severity;
  final List<String> symptoms;
  final List<String> dos;
  final List<String> donts;
  final List<Map<String, dynamic>> assessmentQuestions;
  final List<String> urgentActions;

  EmergencyCondition({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.symptoms,
    required this.dos,
    required this.donts,
    required this.assessmentQuestions,
    required this.urgentActions,
  });

  factory EmergencyCondition.fromJson(Map<String, dynamic> json) {
    return EmergencyCondition(
      id: json['id'] ?? 'unknown_id', // Added fallback
      title: json['title'] ?? 'Unknown Title', // Added fallback
      description: json['description'] ?? '', // Added fallback
      severity: json['severity'] ?? 'medium', // Added fallback
      symptoms:
          json['symptoms'] != null ? List<String>.from(json['symptoms']) : [],
      dos: json['dos'] != null ? List<String>.from(json['dos']) : [],
      donts: json['donts'] != null ? List<String>.from(json['donts']) : [],
      assessmentQuestions: json['assessment_questions'] != null
          ? List<Map<String, dynamic>>.from(json['assessment_questions'])
          : [],
      urgentActions: json['urgent_actions'] != null
          ? List<String>.from(json['urgent_actions'])
          : [],
    );
  }
}

// Singleton service to manage loading and access to medical knowledge data
class MedicalKnowledgeService {
  static final MedicalKnowledgeService _instance =
      MedicalKnowledgeService._internal();

  factory MedicalKnowledgeService() {
    return _instance;
  }

  MedicalKnowledgeService._internal();

  Map<String, EmergencyCondition> _emergencyConditions = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String data =
          await rootBundle.loadString('assets/data/medical_knowledge.json');
      final Map<String, dynamic> jsonData = json.decode(data);
      final List<dynamic> emergencies =
          jsonData['emergencies'] ?? []; // Handle missing key

      for (final emergency in emergencies) {
        if (emergency is Map<String, dynamic>) {
          // Type check
          final EmergencyCondition condition =
              EmergencyCondition.fromJson(emergency);
          _emergencyConditions[condition.id] = condition;
        }
      }

      _isInitialized = true;
      debugPrint(
          'Medical Knowledge Service initialized with ${_emergencyConditions.length} conditions');
    } catch (e) {
      debugPrint('Error initializing Medical Knowledge Service: $e');
      _createFallbackDataset(); // Use fallback on error
    }
  }

  // Creates a minimal dataset if loading from JSON fails
  void _createFallbackDataset() {
    _emergencyConditions = {
      'heart_attack': EmergencyCondition(
        id: 'heart_attack',
        title: 'Heart Attack',
        description:
            'A heart attack occurs when blood flow to part of the heart is blocked.',
        severity: 'high',
        symptoms: ['Chest pain', 'Shortness of breath', 'Sweating', 'Nausea'],
        dos: [
          'Call emergency services immediately',
          'Stay calm',
          'Take aspirin if not allergic'
        ],
        donts: ['Don\'t leave the person alone', 'Don\'t delay seeking help'],
        assessmentQuestions: [],
        urgentActions: [
          'Call emergency services immediately',
          'Help the person sit comfortably'
        ],
      ),
      'stroke': EmergencyCondition(
        id: 'stroke',
        title: 'Stroke',
        description:
            'A stroke occurs when blood supply to part of the brain is interrupted.',
        severity: 'high',
        symptoms: [
          'Sudden numbness',
          'Confusion',
          'Trouble speaking',
          'Severe headache'
        ],
        dos: [
          'Call emergency services immediately',
          'Note when symptoms started'
        ],
        donts: ['Don\'t give food or drink', 'Don\'t delay medical attention'],
        assessmentQuestions: [],
        urgentActions: ['Call emergency services immediately'],
      ),
      // Add other critical fallbacks if necessary
    };
    _isInitialized = true; // Mark as initialized even with fallback
    debugPrint(
        'Created fallback medical knowledge dataset with ${_emergencyConditions.length} conditions');
  }

  List<EmergencyCondition> getAllEmergencyConditions() {
    return _emergencyConditions.values.toList();
  }

  List<EmergencyCondition> getEmergencyConditionsBySeverity(String severity) {
    return _emergencyConditions.values
        .where((condition) =>
            condition.severity.toLowerCase() == severity.toLowerCase())
        .toList();
  }

  List<EmergencyCondition> getHighPriorityEmergencies() {
    return getEmergencyConditionsBySeverity('high');
  }

  EmergencyCondition? getEmergencyCondition(String id) {
    return _emergencyConditions[id];
  }

  List<Map<String, dynamic>> getAssessmentQuestions(String emergencyId) {
    return _emergencyConditions[emergencyId]?.assessmentQuestions ?? [];
  }

  Map<String, List<String>> getEmergencyActions(String emergencyId) {
    final condition = _emergencyConditions[emergencyId];
    return {
      'dos': condition?.dos ?? [],
      'donts': condition?.donts ?? [],
    };
  }

  List<String> getUrgentActions(String emergencyId) {
    return _emergencyConditions[emergencyId]?.urgentActions ?? [];
  }

  List<EmergencyCondition> searchEmergencyConditions(String query) {
    if (query.isEmpty) return [];
    final queryLower = query.toLowerCase();
    return _emergencyConditions.values.where((condition) {
      return condition.title.toLowerCase().contains(queryLower) ||
          condition.description.toLowerCase().contains(queryLower) ||
          condition.symptoms.any((s) => s.toLowerCase().contains(queryLower));
    }).toList();
  }

  // Provides basic info based on severity string (used for UI cues)
  Map<String, dynamic> getSeverityInfo(String severity) {
    final lowerSeverity = severity.toLowerCase();
    switch (lowerSeverity) {
      case 'high':
        return {
          'title': 'High Severity',
          'description': 'Requires immediate medical attention',
          'color': 0xFFFF0000,
          'icon': 'warning'
        };
      case 'medium':
        return {
          'title': 'Medium Severity',
          'description': 'May require prompt medical attention',
          'color': 0xFFFF9800,
          'icon': 'warning_amber'
        };
      case 'low':
        return {
          'title': 'Low Severity',
          'description': 'May be manageable with home care',
          'color': 0xFF4CAF50,
          'icon': 'info'
        };
      default:
        return {
          'title': 'Unknown Severity',
          'description': 'Consult a healthcare professional',
          'color': 0xFF9E9E9E,
          'icon': 'help'
        };
    }
  }
}
