// lib/models/emergency_assessment_data.dart
import 'dart:convert'; // Keep this

// --- EmergencyQuestion Model ---
class EmergencyQuestion {
  final String id;
  final String question; // Internal Dart name for the question text
  final String? description;
  final String type; // 'multiple_choice', 'boolean', 'slider', 'text', 'info'
  final List<Map<String, dynamic>>? options; // For multiple choice
  final double? min; // For slider
  final double? max; // For slider
  final int? divisions; // For slider
  final double? defaultValue; // For slider
  final Map<String, dynamic>?
      condition; // For conditional questions { "dependsOn": "question_id", "equals": value }
  final List<Map<String, dynamic>>?
      jumps; // For branching logic { "whenAnswerIs": value, "toQuestion": "target_question_id" }
  final String?
      noticeType; // For info type questions (warning, danger, info, success)
  final String? content; // For info type questions

  EmergencyQuestion({
    required this.id,
    required this.question,
    this.description,
    required this.type,
    this.options,
    this.min,
    this.max,
    this.divisions,
    this.defaultValue,
    this.condition,
    this.jumps,
    this.noticeType,
    this.content,
  });

  // Factory to create an EmergencyQuestion from a JSON map
  factory EmergencyQuestion.fromJson(Map<String, dynamic> json) {
    // Calculate divisions for slider if min/max are present but divisions are not
    int? calculatedDivisions;
    if (json['type'] == 'slider' &&
        json['max'] != null &&
        json['min'] != null &&
        json['divisions'] == null) {
      double maxVal = json['max'].toDouble();
      double minVal = json['min'].toDouble();
      // Ensure max > min to avoid negative/zero divisions
      if (maxVal > minVal) {
        calculatedDivisions = (maxVal - minVal).toInt();
      }
    }

    return EmergencyQuestion(
      id: json['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(), // Fallback ID
      question: json['text'] ??
          'Missing question text', // Use 'text' from JSON, provide fallback
      description: json['description'],
      type: json['type'] ?? 'info', // Default to 'info' if type is missing
      options: json['options'] != null
          ? List<Map<String, dynamic>>.from(json['options'])
          : null,
      min: json['min']?.toDouble(),
      max: json['max']?.toDouble(),
      // Use calculated divisions if available, otherwise use JSON value or null
      divisions: calculatedDivisions ?? json['divisions'],
      defaultValue: json['defaultValue']?.toDouble(),
      condition: json['condition'] != null
          ? Map<String, dynamic>.from(json['condition'])
          : null,
      jumps: json['jumps'] != null
          ? List<Map<String, dynamic>>.from(json['jumps'])
          : null,
      noticeType: json['noticeType'],
      content: json['content'],
    );
  }

  // Method to convert an EmergencyQuestion instance back to JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'text': question, // Map back to 'text' for consistency with input JSON
      'type': type,
    };
    // Add optional fields only if they exist
    if (description != null) data['description'] = description;
    if (options != null) data['options'] = options;
    if (min != null) data['min'] = min;
    if (max != null) data['max'] = max;
    // Only include divisions if it was originally provided or reasonably calculated
    if (divisions != null &&
        (max == null || min == null || divisions != (max! - min!).toInt())) {
      data['divisions'] = divisions;
    }
    if (defaultValue != null) data['defaultValue'] = defaultValue;
    if (condition != null) data['condition'] = condition;
    if (jumps != null) data['jumps'] = jumps;
    if (noticeType != null) data['noticeType'] = noticeType;
    if (content != null) data['content'] = content;
    return data;
  }
}

// --- EmergencyAdvice Model ---
// Represents the Do's, Don'ts, and general description for an emergency type.
class EmergencyAdvice {
  final List<String> dos;
  final List<String> donts;
  final String description;

  EmergencyAdvice({
    required this.dos,
    required this.donts,
    required this.description,
  });

  // Factory to create EmergencyAdvice from a JSON map (usually part of the main emergency object)
  factory EmergencyAdvice.fromJson(Map<String, dynamic> json) {
    return EmergencyAdvice(
      dos: List<String>.from(
          json['dos'] ?? []), // Handle potentially missing 'dos' list
      donts: List<String>.from(
          json['donts'] ?? []), // Handle potentially missing 'donts' list
      description: json['description'] ??
          'No description provided.', // Handle missing description
    );
  }

  // Method to convert EmergencyAdvice back to JSON (useful if saving)
  Map<String, dynamic> toJson() {
    return {
      'dos': dos,
      'donts': donts,
      'description': description,
    };
  }
}

// --- EmergencyAssessmentData Model ---
// Represents the complete configuration for a specific emergency assessment.
class EmergencyAssessmentData {
  final String id;
  final String title;
  final List<EmergencyQuestion> questions; // The assessment questions
  final EmergencyAdvice advice; // Contains Do's, Don'ts, Description
  final bool isHighPriority;
  final String? color; // Hex color string (e.g., "#FF0000")
  final String? icon; // Icon name (e.g., "favorite") - Requires mapping in UI

  EmergencyAssessmentData({
    required this.id,
    required this.title,
    required this.questions,
    required this.advice,
    this.isHighPriority = false,
    this.color,
    this.icon,
  });

  // Factory to create EmergencyAssessmentData from a JSON map representing one emergency type
  factory EmergencyAssessmentData.fromJson(Map<String, dynamic> json) {
    return EmergencyAssessmentData(
      id: json['id'] ?? 'unknown_emergency', // Provide a fallback ID
      title: json['title'] ?? 'Unknown Emergency', // Provide a fallback title
      // Parse questions, ensuring the list exists
      questions: (json['questions'] as List? ?? [])
          .map((q) => EmergencyQuestion.fromJson(
              q as Map<String, dynamic>)) // Ensure 'q' is treated as a map
          .toList(),
      // Create advice directly from the top-level JSON fields
      advice: EmergencyAdvice.fromJson(
          json), // Pass the whole json map to advice factory
      isHighPriority: json['highPriority'] ??
          false, // Use correct key from JSON, default to false
      color: json['color'], // Can be null
      icon: json['icon'], // Can be null
    );
  }

  // Method to convert EmergencyAssessmentData back to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': advice.description, // Flatten advice back
      'color': color,
      'icon': icon,
      'highPriority': isHighPriority,
      'dos': advice.dos,
      'donts': advice.donts,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
