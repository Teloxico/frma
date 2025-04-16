// lib/pages/emergency_assessment_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../models/emergency_assessment_data.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../providers/profile_provider.dart';

class EmergencyAssessmentPage extends StatefulWidget {
  final String emergencyType;
  final bool isSelf;
  final String locationInfo;

  const EmergencyAssessmentPage({
    Key? key,
    required this.emergencyType,
    required this.isSelf,
    required this.locationInfo,
  }) : super(key: key);

  @override
  State<EmergencyAssessmentPage> createState() =>
      _EmergencyAssessmentPageState();
}

class _EmergencyAssessmentPageState extends State<EmergencyAssessmentPage> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  // State for assessment data loaded from JSON
  EmergencyAssessmentData? _assessmentConfig;
  List<EmergencyQuestion> _assessmentQuestions = [];
  List<String> _dos = [];
  List<String> _donts = [];
  String _emergencyDescription = '';

  // State for user answers and patient data (if not self)
  final Map<String, dynamic> _answers = {};
  final Map<String, dynamic> _patientData = {'is_self': false};

  // Assessment flow control
  int _currentQuestionIndex = 0;
  int _assessmentStage =
      0; // 0: intro, 1: patient info, 2: assessment, 3: results
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showEmergencyCallButton = false;

  // Results state
  String? _aiInstructions;

  // UI and other state variables
  String _errorMessage = '';
  String _updatedLocationInfo = '';
  double _progressValue = 0.0;

  // Patient Info Form Controllers (only if !isSelf)
  final _patientNameController = TextEditingController();
  final _patientAgeController = TextEditingController();
  String _patientGender = '';
  final _patientConditionsController = TextEditingController();
  final _patientAllergiesController = TextEditingController();
  final _patientMedicationsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updatedLocationInfo = widget.locationInfo;
    _initializePatientData();
    _loadEmergencyData();
    _updateLocationInBackground();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _patientConditionsController.dispose();
    _patientAllergiesController.dispose();
    _patientMedicationsController.dispose();
    super.dispose();
  }

  // Initialize patient data structure
  void _initializePatientData() {
    if (widget.isSelf) {
      _patientData['is_self'] = true;
    } else {
      _patientData['is_self'] = false;
      _patientData['name'] = '';
      _patientData['age'] = null;
      _patientData['gender'] = '';
      _patientData['medical_conditions'] = '';
      _patientData['allergies'] = '';
      _patientData['medications'] = '';
      _patientGender = '';
    }
  }

  // Load specific emergency data from the JSON file
  Future<void> _loadEmergencyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/emergencies.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> emergenciesList = jsonData['emergencies'];
      final emergencyJson = emergenciesList.firstWhere(
          (e) => e['id'] == widget.emergencyType,
          orElse: () => null);

      if (emergencyJson == null) {
        throw Exception('Emergency type "${widget.emergencyType}" not found.');
      }

      _assessmentConfig = EmergencyAssessmentData.fromJson(emergencyJson);
      _assessmentQuestions = List.from(_assessmentConfig!.questions);
      if (!widget.isSelf) {
        _assessmentQuestions.insertAll(0, _getPatientInfoQuestions());
      }
      _dos = _assessmentConfig!.advice.dos;
      _donts = _assessmentConfig!.advice.donts;
      _emergencyDescription = _assessmentConfig!.advice.description;
      _showEmergencyCallButton = _assessmentConfig!.isHighPriority;

      setState(() {
        _isLoading = false;
        _updateProgressValue();
      });
    } catch (e) {
      debugPrint('Error loading emergency data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load assessment data: ${e.toString()}';
      });
    }
  }

  // Update location in the background
  Future<void> _updateLocationInBackground() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _updatedLocationInfo = location);
    } catch (e) {
      debugPrint("Failed to update location: $e");
    }
  }

  // Define Patient Info Questions (Conceptual mapping to UI)
  List<EmergencyQuestion> _getPatientInfoQuestions() {
    return [
      EmergencyQuestion(
          id: 'patient_info_intro',
          question: 'Patient Information',
          type: 'info',
          content:
              'Please provide basic information about the person needing assistance.'),
      EmergencyQuestion(
          id: 'patient_name',
          question: 'Patient\'s Name (Optional)',
          type: 'text'),
      EmergencyQuestion(
          id: 'patient_age', question: 'Approximate Age (Years)', type: 'text'),
      EmergencyQuestion(
          id: 'patient_gender',
          question: 'Gender',
          type: 'multiple_choice',
          options: [
            {'text': 'Male', 'value': 'Male'},
            {'text': 'Female', 'value': 'Female'},
            {'text': 'Other', 'value': 'Other'},
            {'text': 'Unknown', 'value': 'Unknown'}
          ]),
      EmergencyQuestion(
          id: 'patient_conditions',
          question: 'Known Major Medical Conditions (Optional)',
          description: 'e.g., Diabetes, Heart Problems',
          type: 'text'),
      EmergencyQuestion(
          id: 'patient_allergies',
          question: 'Known Allergies (Optional)',
          description: 'e.g., Penicillin, Nuts',
          type: 'text'),
      EmergencyQuestion(
          id: 'patient_meds',
          question: 'Current Medications (Optional)',
          description: 'List names if known',
          type: 'text'),
    ];
  }

  // Update progress bar value based on stage and index
  void _updateProgressValue() {
    if (_assessmentQuestions.isEmpty) {
      _progressValue = 0.0;
      return;
    }
    int totalQuestions = _assessmentQuestions.length;
    int patientQuestionsCount =
        widget.isSelf ? 0 : _getPatientInfoQuestions().length;
    int currentEffectiveIndex = 0;

    if (_assessmentStage == 0)
      currentEffectiveIndex = 0;
    else if (_assessmentStage == 1)
      currentEffectiveIndex = _currentQuestionIndex;
    else if (_assessmentStage == 2)
      currentEffectiveIndex = patientQuestionsCount + _currentQuestionIndex;
    else if (_assessmentStage == 3) currentEffectiveIndex = totalQuestions;

    _progressValue = (currentEffectiveIndex / totalQuestions).clamp(0.0, 1.0);
  }

  // Check if a question should be skipped
  bool _shouldSkipQuestion(EmergencyQuestion question) {
    if (question.condition == null) return false;
    Map<String, dynamic> condition = question.condition!;
    String dependsOn = condition['dependsOn'];
    dynamic expectedValue = condition['equals'];
    if (!_answers.containsKey(dependsOn)) return false;
    return _answers[dependsOn] != expectedValue;
  }

  // Move to the next question or stage
  void _nextQuestion(dynamic answer) {
    HapticFeedback.selectionClick();
    int currentAbsoluteIndex = _currentQuestionIndex;
    if (!widget.isSelf && _assessmentStage == 2) {
      currentAbsoluteIndex += _getPatientInfoQuestions().length;
    }

    if (currentAbsoluteIndex < 0 ||
        currentAbsoluteIndex >= _assessmentQuestions.length) {
      debugPrint("Error: Invalid index $currentAbsoluteIndex in _nextQuestion");
      _submitAssessment();
      return;
    }

    // Save current answer
    final currentQuestion = _assessmentQuestions[currentAbsoluteIndex];
    if (_assessmentStage == 1) {
      // Patient Info Stage
      String questionId = currentQuestion.id;
      if (questionId == 'patient_name')
        _patientData['name'] = _patientNameController.text.trim();
      else if (questionId == 'patient_age')
        _patientData['age'] = int.tryParse(_patientAgeController.text.trim());
      else if (questionId == 'patient_gender')
        _patientData['gender'] = answer;
      else if (questionId == 'patient_conditions')
        _patientData['medical_conditions'] =
            _patientConditionsController.text.trim();
      else if (questionId == 'patient_allergies')
        _patientData['allergies'] = _patientAllergiesController.text.trim();
      else if (questionId == 'patient_meds')
        _patientData['medications'] = _patientMedicationsController.text.trim();
      _answers[questionId] = answer;
    } else if (_assessmentStage == 2) {
      // Main Assessment Stage
      _answers[currentQuestion.id] = answer;
    }

    // Check for jumps
    if (currentQuestion.jumps != null) {
      for (var jump in currentQuestion.jumps!) {
        if (jump['whenAnswerIs'] == answer) {
          int targetIndex = _assessmentQuestions
              .indexWhere((q) => q.id == jump['toQuestion']);
          if (targetIndex != -1) {
            int targetStageRelativeIndex = targetIndex;
            if (!widget.isSelf && _assessmentStage == 2) {
              targetStageRelativeIndex -= _getPatientInfoQuestions().length;
            }

            if (targetStageRelativeIndex >= 0) {
              setState(() {
                _currentQuestionIndex = targetStageRelativeIndex;
                _updateProgressValue();
              });
              return;
            }
          }
        }
      }
    }

    // --- Stage Progression ---
    int patientQuestionsCount =
        widget.isSelf ? 0 : _getPatientInfoQuestions().length;
    if (_assessmentStage == 0) {
      setState(() {
        _assessmentStage = widget.isSelf ? 2 : 1;
        _currentQuestionIndex = 0;
        _updateProgressValue();
      });
      return;
    } else if (_assessmentStage == 1 &&
        _currentQuestionIndex >= patientQuestionsCount - 1) {
      setState(() {
        _assessmentStage = 2;
        _currentQuestionIndex = 0;
        _updateProgressValue();
      });
      return;
    }

    // --- Question Progression within current stage ---
    int currentMaxIndexInStage = 0;
    if (_assessmentStage == 1)
      currentMaxIndexInStage = patientQuestionsCount - 1;
    else if (_assessmentStage == 2)
      currentMaxIndexInStage =
          (_assessmentQuestions.length - patientQuestionsCount) - 1;

    if (_currentQuestionIndex >= currentMaxIndexInStage) {
      // End of the current stage (or total assessment if stage 2)
      _submitAssessment();
      return;
    }

    // Find next non-skipped question index within the stage
    int nextStageIndex = _currentQuestionIndex + 1;
    while (nextStageIndex <= currentMaxIndexInStage) {
      int nextAbsoluteIndex = nextStageIndex;
      if (!widget.isSelf && _assessmentStage == 2) {
        nextAbsoluteIndex += patientQuestionsCount;
      }
      if (nextAbsoluteIndex < _assessmentQuestions.length &&
          !_shouldSkipQuestion(_assessmentQuestions[nextAbsoluteIndex])) {
        setState(() {
          _currentQuestionIndex = nextStageIndex;
          _updateProgressValue();
        });
        return;
      }
      nextStageIndex++;
    }

    // If all remaining questions in the stage are skipped
    _submitAssessment();
  }

  // Go back to the previous question or stage
  void _previousQuestion() {
    HapticFeedback.selectionClick();

    if (_currentQuestionIndex > 0) {
      // Can move back within the current stage
      // Find the previous non-skipped question within the stage
      int prevStageIndex = _currentQuestionIndex - 1;
      while (prevStageIndex >= 0) {
        int prevAbsoluteIndex = prevStageIndex;
        if (!widget.isSelf && _assessmentStage == 2) {
          prevAbsoluteIndex += _getPatientInfoQuestions().length;
        }
        if (prevAbsoluteIndex >= 0 &&
            prevAbsoluteIndex < _assessmentQuestions.length &&
            !_shouldSkipQuestion(_assessmentQuestions[prevAbsoluteIndex])) {
          setState(() {
            _currentQuestionIndex = prevStageIndex;
            _updateProgressValue();
          });
          return;
        }
        prevStageIndex--;
      }
      // If loop finishes, it means we are at the start of the stage, handle stage transition below
    }

    // --- Stage Decrement Logic ---
    if (_assessmentStage == 2 && !widget.isSelf) {
      // From Assessment back to Patient Info
      setState(() {
        _assessmentStage = 1;
        _currentQuestionIndex = _getPatientInfoQuestions().length - 1;
        _updateProgressValue();
      });
    } else if (_assessmentStage == 1 ||
        (_assessmentStage == 2 && widget.isSelf)) {
      // From Patient Info/Assessment(self) back to Intro
      setState(() {
        _assessmentStage = 0;
        _currentQuestionIndex = 0;
        _updateProgressValue();
      });
    }
  }

  // Submit assessment answers to AI
  Future<void> _submitAssessment() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      Map<String, dynamic> finalPatientData;
      if (widget.isSelf) {
        finalPatientData = {
          /* ... populate from profileProvider ... */
          'is_self': true,
          'name': profileProvider.name.isEmpty ? 'Self' : profileProvider.name,
          'age': profileProvider.age,
          'gender': profileProvider.gender,
          'weight_kg':
              profileProvider.weight > 0 ? profileProvider.weight : null,
          'height_cm':
              profileProvider.height > 0 ? profileProvider.height : null,
          'blood_type': profileProvider.bloodType.isEmpty
              ? null
              : profileProvider.bloodType,
          'medical_conditions': profileProvider.medicalConditions
              .where((c) => c.selected)
              .map((c) => c.name)
              .toList(),
          'allergies': profileProvider.allergies,
          'medications': profileProvider.medications
              .map((m) => '${m.name} (${m.dosage}, ${m.frequency})')
              .toList(),
        };
      } else {
        finalPatientData = Map.from(_patientData);
      }

      String formattedAnswers = _answers.entries.map((entry) {
        final questionText = _assessmentQuestions
            .firstWhere((q) => q.id == entry.key,
                orElse: () => EmergencyQuestion(
                    id: entry.key, question: entry.key, type: 'unknown'))
            .question;
        return "Q: ${questionText}\nA: ${entry.value?.toString() ?? 'Not answered'}";
      }).join('\n\n');

      final prompt = """
      **Emergency Assessment Analysis Request**
      **Emergency Type:** ${_assessmentConfig?.title ?? widget.emergencyType.toUpperCase()}
      **Patient Information:**
      ${finalPatientData.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map((e) => "- ${e.key.replaceAll('_', ' ').capitalize()}: ${e.value}").join('\n')}
      **Assessment Answers:**
      $formattedAnswers
      **Location Context:** $_updatedLocationInfo
      **Instructions Requested:**
      Based *only* on the information provided above, generate clear, concise, step-by-step first aid instructions suitable for a layperson. Prioritize immediate life-saving actions. Be direct and avoid overly technical jargon. Do *not* provide a diagnosis. Start the response directly with the instructions using numbered or bulleted points.
      """;

      debugPrint("--- AI Prompt ---\n$prompt\n--- End AI Prompt ---");

      final result = await _apiService.sendMedicalQuestion(
          question: prompt.trim(),
          messageHistory: [],
          maxTokens: 768,
          temperature: 0.3);

      if (mounted) {
        setState(() {
          _aiInstructions =
              result['answer'] ?? 'Error: No instructions received.';
          _assessmentStage = 3;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _assessmentStage = 3;
          _errorMessage =
              e is ApiServiceException ? e.message : 'Failed: ${e.toString()}';
          _aiInstructions = "Error retrieving instructions:\n$_errorMessage";
        });
      }
    }
  }

  // Call emergency services
  Future<void> _callEmergency() async {
    HapticFeedback.heavyImpact();
    final Uri phoneUri = Uri(scheme: 'tel', path: '911');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch call')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error calling: $e')));
    }
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
          elevation: 2.0,
        ),
        body: _buildBody(),
        bottomNavigationBar:
            _showEmergencyCallButton ? _buildEmergencyCallBar() : null,
      ),
    );
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (_assessmentStage > 0 && _assessmentStage < 3) {
      bool shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text('Exit Assessment?'),
                    content: const Text('Progress will be lost.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error),
                          child: const Text('Exit')),
                    ],
                  )) ??
          false;
      return shouldPop;
    }
    return true;
  }

  // Determine AppBar Title
  String _getAppBarTitle() {
    return '${_assessmentConfig?.title ?? widget.emergencyType.replaceAll('_', ' ').capitalize()} Assessment';
  }

  // Build the main body based on the current stage
  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty && _assessmentStage != 3)
      return _buildErrorView();
    if (_assessmentConfig == null && _assessmentStage != 3)
      return _buildErrorView(message: "Config missing.");

    switch (_assessmentStage) {
      case 0:
        return _buildIntroInformation();
      case 1:
        return _buildPatientInfoForm();
      case 2:
        return _assessmentQuestions.isEmpty
            ? const Center(child: Text('No questions.'))
            : _buildQuestionCard();
      case 3:
        return _buildAssessmentResults();
      default:
        return const Center(child: Text('Invalid stage.'));
    }
  }

  // Error View Widget
  Widget _buildErrorView({String? message}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 60),
              const SizedBox(height: 16),
              Text('Error Loading Assessment',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: colorScheme.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(message ?? _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  onPressed: () => Navigator.maybePop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceVariant))
            ])));
  }

  // Build the introductory screen
  Widget _buildIntroInformation() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.error.withOpacity(0.3))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_assessmentConfig!.title.toUpperCase(),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.error)),
                    const SizedBox(height: 8),
                    Text(_emergencyDescription,
                        style: theme.textTheme.bodyLarge),
                  ])),
          const SizedBox(height: 24),
          Text('WHAT TO DO',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green)),
          const SizedBox(height: 12),
          ..._dos.map(
              (item) => _buildListItem(item, Icons.check_circle, Colors.green)),
          const SizedBox(height: 24),
          Text('WHAT NOT TO DO',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error)),
          const SizedBox(height: 12),
          ..._donts.map(
              (item) => _buildListItem(item, Icons.cancel, colorScheme.error)),
          const SizedBox(height: 32),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Text(
                    'This assessment asks questions to understand the situation...',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Text(
                    widget.isSelf
                        ? 'Profile info may be used.'
                        : 'You will be asked for patient info.',
                    style: const TextStyle(fontSize: 16)),
              ])),
          const SizedBox(height: 32),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('START ASSESSMENT'),
                onPressed: () => _nextQuestion(null),
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              )),
          const SizedBox(height: 24),
          if (_showEmergencyCallButton) _buildDirectCallButton(),
          const SizedBox(height: 16),
          if (_showEmergencyCallButton) _buildPriorityDisclaimer(),
        ]));
  }

  // Helper for Do's/Don'ts list items
  Widget _buildListItem(String text, IconData icon, Color color) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ]));
  }

  // Direct Emergency Call Button
  Widget _buildDirectCallButton() {
    final theme = Theme.of(context);

    return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _callEmergency,
          icon: Icon(Icons.call, color: theme.colorScheme.error),
          label: Text('CALL EMERGENCY SERVICES DIRECTLY',
              style: TextStyle(color: theme.colorScheme.error)),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 16)),
        ));
  }

  // Priority Disclaimer
  Widget _buildPriorityDisclaimer() {
    final theme = Theme.of(context);
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.priority_high, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'If life-threatening, call emergency services immediately.',
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 14))),
        ]));
  }

  // Build Form for Patient Info (if !isSelf)
  Widget _buildPatientInfoForm() {
    final theme = Theme.of(context);

    if (_assessmentStage != 1 ||
        _currentQuestionIndex >= _getPatientInfoQuestions().length) {
      return _buildErrorView(message: "Invalid state for patient info form.");
    }
    final question = _assessmentQuestions[_currentQuestionIndex];
    int displayIndex = _currentQuestionIndex;

    return Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: theme.colorScheme.surfaceVariant,
              color: theme.colorScheme.primary,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          Text(
              'Patient Information (${displayIndex + 1}/${_getPatientInfoQuestions().length})',
              style: TextStyle(
                  fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Text(question.question,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (question.description != null)
            Text(question.description!,
                style: TextStyle(
                    fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          Expanded(child: _buildPatientInfoInput(question)),
          if (!_isSubmitting) _buildNavigationButtons(isPatientInfoStage: true),
        ]));
  }

  // Builds the specific input field for the patient info stage
  Widget _buildPatientInfoInput(EmergencyQuestion question) {
    final theme = Theme.of(context);

    // This renders the actual UI based on the conceptual question ID
    switch (question.id) {
      case 'patient_info_intro':
        return _buildInfoNotice(question); // Special case for intro notice
      case 'patient_name':
        return TextFormField(
            controller: _patientNameController,
            decoration: const InputDecoration(
                labelText: 'Name', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_age':
        return TextFormField(
            controller: _patientAgeController,
            decoration: const InputDecoration(
                labelText: 'Age (years)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_gender':
        return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (question.options ?? []).map((option) {
              return RadioListTile<String>(
                  title: Text(option['text']),
                  value: option['value'],
                  groupValue: _patientGender,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _patientGender = value);
                      Future.delayed(const Duration(milliseconds: 250),
                          () => _nextQuestion(value));
                    }
                  },
                  activeColor: theme.colorScheme.primary,
                  contentPadding: EdgeInsets.zero);
            }).toList());
      case 'patient_conditions':
        return TextFormField(
            controller: _patientConditionsController,
            decoration: const InputDecoration(
                labelText: 'Known Conditions', border: OutlineInputBorder()),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_allergies':
        return TextFormField(
            controller: _patientAllergiesController,
            decoration: const InputDecoration(
                labelText: 'Known Allergies', border: OutlineInputBorder()),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: (v) => _nextQuestion(v));
      case 'patient_meds':
        return TextFormField(
            controller: _patientMedicationsController,
            decoration: const InputDecoration(
                labelText: 'Current Medications', border: OutlineInputBorder()),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: (v) => _nextQuestion(v));
      default:
        return Center(
            child: Text('Unknown patient info field: ${question.id}'));
    }
  }

  // Build the main question card for the assessment stage
  Widget _buildQuestionCard() {
    final theme = Theme.of(context);

    int questionListIndex = _currentQuestionIndex;
    if (!widget.isSelf && _assessmentStage == 2) {
      questionListIndex += _getPatientInfoQuestions().length;
    }
    if (questionListIndex < 0 ||
        questionListIndex >= _assessmentQuestions.length) {
      return _buildErrorView(message: "Invalid question index.");
    }
    final currentQuestion = _assessmentQuestions[questionListIndex];
    int displayQuestionNumber = widget.isSelf
        ? (_currentQuestionIndex + 1)
        : (_currentQuestionIndex + 1);
    int totalDisplayQuestions = widget.isSelf
        ? _assessmentConfig?.questions.length ?? 0
        : (_assessmentConfig?.questions.length ?? 0);

    return Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Column(children: [
            LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: theme.colorScheme.surfaceVariant,
                color: theme.colorScheme.error,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Question $displayQuestionNumber of $totalDisplayQuestions',
                  style: TextStyle(
                      fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.3))),
                child: Text(_assessmentConfig!.title.toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error)),
              )
            ]),
          ]),
          const SizedBox(height: 24),
          Text(currentQuestion.question,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (currentQuestion.description != null)
            Text(currentQuestion.description!,
                style: TextStyle(
                    fontSize: 16, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          Expanded(child: _buildAnswerWidget(currentQuestion)),
          if (!_isSubmitting) _buildNavigationButtons(),
          if (_isSubmitting) _buildSubmittingIndicator(),
        ]));
  }

  // Build the appropriate widget for the current question's type
  Widget _buildAnswerWidget(EmergencyQuestion question) {
    switch (question.type) {
      case 'multiple_choice':
        return _buildMultipleChoiceQuestion(question);
      case 'boolean':
        return _buildBooleanQuestion(question);
      case 'slider':
        return _buildSliderQuestion(question);
      case 'text':
        return _buildTextQuestion(question);
      case 'info':
        return _buildInfoNotice(question);
      default:
        debugPrint("Unsupported question type: ${question.type}");
        return const Center(child: Text('Unsupported question type'));
    }
  }

  // --- Widgets for Specific Question Types ---

  Widget _buildMultipleChoiceQuestion(EmergencyQuestion question) {
    final theme = Theme.of(context);
    final List<dynamic> options = question.options ?? [];
    final bool useRadio = question.toJson()['display'] == 'radio';
    if (useRadio) {
      String? currentAnswer = _answers[question.id]?.toString();
      return StatefulBuilder(builder: (context, setRadioState) {
        return ListView(
            shrinkWrap: true,
            children: options.map((option) {
              final String optionValue = option['value'].toString();
              return RadioListTile<String>(
                  title: Text(option['text']),
                  value: optionValue,
                  groupValue: currentAnswer,
                  onChanged: (value) {
                    if (value != null) {
                      setRadioState(() => currentAnswer = value);
                      Future.delayed(const Duration(milliseconds: 200),
                          () => _nextQuestion(option['value']));
                    }
                  },
                  activeColor: theme.colorScheme.error,
                  subtitle: option['description'] != null
                      ? Text(option['description'])
                      : null);
            }).toList());
      });
    } else {
      return ListView.builder(
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                    onTap: _isSubmitting
                        ? null
                        : () => _nextQuestion(option['value']),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option['text'],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500)),
                              if (option['description'] != null) ...[
                                const SizedBox(height: 4),
                                Text(option['description'],
                                    style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant))
                              ],
                            ]))));
          });
    }
  }

  Widget _buildBooleanQuestion(EmergencyQuestion question) {
    final theme = Theme.of(context);

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton(
          onPressed: _isSubmitting ? null : () => _nextQuestion(true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('Yes', style: TextStyle(fontSize: 18))),
      const SizedBox(height: 16),
      ElevatedButton(
          onPressed: _isSubmitting ? null : () => _nextQuestion(false),
          style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: const Text('No', style: TextStyle(fontSize: 18))),
    ]);
  }

  Widget _buildSliderQuestion(EmergencyQuestion question) {
    final double min = question.min ?? 0.0;
    final double max = question.max ?? 10.0;
    final int divisions =
        question.divisions ?? (max - min).clamp(1, 100).toInt();
    final double initialValue =
        (_answers[question.id] as double?) ?? question.defaultValue ?? min;

    return StatefulBuilder(builder: (context, setState) {
      double value = initialValue.clamp(min, max);
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: _getSliderColor(value, min, max).withOpacity(0.1),
                shape: BoxShape.circle),
            child: Text('${value.toInt()}',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _getSliderColor(value, min, max)))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(question.description?.split(',')[0] ?? 'Min',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          Text(question.description?.split(',').last ?? 'Max',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.red.shade700))
        ]),
        Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.toInt()}',
            activeColor: _getSliderColor(value, min, max),
            onChanged: (newValue) => setState(() => value = newValue)),
        const SizedBox(height: 32),
        ElevatedButton(
            onPressed: _isSubmitting ? null : () => _nextQuestion(value),
            style: ElevatedButton.styleFrom(
                backgroundColor: _getSliderColor(value, min, max),
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.white),
            child: const Text('Next')),
      ]);
    });
  }

  Color _getSliderColor(double value, double min, double max) {
    if (max <= min) return Colors.blue;
    final double percentage = (value - min) / (max - min);
    if (percentage < 0.3) return Colors.green;
    if (percentage < 0.7) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTextQuestion(EmergencyQuestion question) {
    final TextEditingController textController =
        TextEditingController(text: _answers[question.id]?.toString() ?? '');
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(
          controller: textController,
          decoration: InputDecoration(
              hintText: question.description ?? 'Enter answer',
              border: const OutlineInputBorder()),
          maxLines: 3,
          onSubmitted: (v) => _nextQuestion(v)),
      const SizedBox(height: 24),
      ElevatedButton(
          onPressed:
              _isSubmitting ? null : () => _nextQuestion(textController.text),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50)),
          child: const Text('Next')),
    ]);
  }

  Widget _buildInfoNotice(EmergencyQuestion question) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color noticeColor = colorScheme.primary;
    IconData noticeIcon = Icons.info_outline;
    switch (question.noticeType) {
      case 'warning':
        noticeColor = Colors.orange;
        noticeIcon = Icons.warning_amber_outlined;
        break;
      case 'danger':
        noticeColor = colorScheme.error;
        noticeIcon = Icons.dangerous_outlined;
        break;
      case 'success':
        noticeColor = Colors.green;
        noticeIcon = Icons.check_circle_outline;
        break;
    }
    bool isPatientIntro = question.id == 'patient_info_intro';

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: noticeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: noticeColor.withOpacity(0.3))),
          child: Column(children: [
            Icon(noticeIcon, color: noticeColor, size: 48),
            const SizedBox(height: 16),
            if (question.content != null)
              Text(question.content!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center)
          ])),
      const Spacer(),
      if (!isPatientIntro)
        ElevatedButton(
            onPressed: _isSubmitting ? null : () => _nextQuestion(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: noticeColor,
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.white),
            child: const Text('Continue')),
      if (!isPatientIntro)
        Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'))),
      if (isPatientIntro)
        Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: ElevatedButton(
                onPressed: () => _nextQuestion(true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('Next'))),
    ]);
  }

  // --- End Question Type Widgets ---

  // Build Navigation Buttons
  Widget _buildNavigationButtons({bool isPatientInfoStage = false}) {
    bool canGoBack = false;
    if (_assessmentStage == 1)
      canGoBack = _currentQuestionIndex > 0;
    else if (_assessmentStage == 2) canGoBack = true;

    if (canGoBack) {
      return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(children: [
            TextButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back')),
            const Spacer(),
          ]));
    }
    return const SizedBox.shrink();
  }

  // Build Submitting Indicator
  Widget _buildSubmittingIndicator() {
    return const Center(
        child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating instructions...')
            ])));
  }

  // Build the results screen displaying AI instructions
  Widget _buildAssessmentResults() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool hasError =
        _aiInstructions != null && _aiInstructions!.startsWith("Error");
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Column(children: [
            Icon(hasError ? Icons.error_outline : Icons.check_circle_outline,
                size: 64, color: hasError ? colorScheme.error : Colors.green),
            const SizedBox(height: 16),
            Text(
                hasError
                    ? 'Error Generating Instructions'
                    : 'Assessment Complete',
                style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasError ? colorScheme.error : null)),
          ])),
          const SizedBox(height: 32),
          Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                              hasError
                                  ? Icons.report_problem_outlined
                                  : Icons.integration_instructions_outlined,
                              color: hasError
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              size: 28),
                          const SizedBox(width: 12),
                          Text(
                              hasError
                                  ? 'Error Details'
                                  : 'First Aid Instructions',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))
                        ]),
                        const Divider(height: 24),
                        SelectableText(
                            _aiInstructions ?? 'Loading instructions...',
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                color: hasError ? colorScheme.error : null)),
                      ]))),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(vertical: 16)))),
            const SizedBox(width: 16),
            Expanded(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call Emergency'),
                    onPressed: _callEmergency,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 16)))),
          ]),
          const SizedBox(height: 16),
          Center(
              child: TextButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share Instructions'),
                  onPressed: _shareAssessmentResults)),
          const SizedBox(height: 24),
          _buildDisclaimer(),
        ]));
  }

  // Share assessment results
  void _shareAssessmentResults() {
    if (_aiInstructions == null ||
        _aiInstructions!.isEmpty ||
        _aiInstructions!.startsWith("Error")) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid instructions to share.')));
      return;
    }
    try {
      final shareText = StringBuffer();
      shareText.writeln(
          'EMERGENCY ASSESSMENT - ${_assessmentConfig?.title?.toUpperCase() ?? widget.emergencyType.toUpperCase()}');
      shareText.writeln('Location: $_updatedLocationInfo');
      if (_answers.isNotEmpty) {
        shareText.writeln('\n--- ASSESSMENT ANSWERS ---');
        _answers.forEach((key, value) {
          final qText = _assessmentQuestions
              .firstWhere((q) => q.id == key,
                  orElse: () =>
                      EmergencyQuestion(id: key, question: key, type: ''))
              .question;
          shareText.writeln("Q: $qText\nA: ${value?.toString() ?? 'N/A'}");
        });
      }
      shareText.writeln('\n--- AI GENERATED INSTRUCTIONS ---');
      shareText.writeln(_aiInstructions);
      shareText.writeln(
          '\nDisclaimer: Provided by Health Assistant app. Not medical advice.');

      Clipboard.setData(ClipboardData(text: shareText.toString()));

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instructions copied to clipboard')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare sharing data: $e')));
    }
  }

  // Disclaimer Widget
  Widget _buildDisclaimer() {
    final theme = Theme.of(context);
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  'Assessment & instructions are informational only, not a substitute for professional medical advice. Call emergency services in life-threatening situations.',
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12)))
        ]));
  }

  Widget _buildEmergencyCallBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        color: colorScheme.error,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ElevatedButton(
          onPressed: _callEmergency,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: colorScheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.call, size: 24),
              SizedBox(width: 10),
              Text(
                'CALL EMERGENCY SERVICES',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    // Handle cases like "hello_world" -> "Hello world"
    String processed = replaceAll('_', ' ');
    if (processed.isEmpty) return "";
    return "${processed[0].toUpperCase()}${processed.substring(1).toLowerCase()}";
  }
}
