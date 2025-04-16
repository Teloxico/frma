// lib/pages/emergency_care_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../widgets/drawer_menu.dart';
import 'emergency_assessment_page.dart';

// --- Data Class Definition ---
class EmergencyData {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool isHighPriority;
  final String description;

  EmergencyData({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.isHighPriority,
    required this.description,
  });
}
// --- End Data Class ---

class EmergencyCarePage extends StatefulWidget {
  const EmergencyCarePage({Key? key}) : super(key: key);

  @override
  State<EmergencyCarePage> createState() => _EmergencyCarePageState();
}

class _EmergencyCarePageState extends State<EmergencyCarePage>
    with SingleTickerProviderStateMixin {
  // Animation
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Timer? _pulseTimer;

  // Location
  final LocationService _locationService = LocationService();
  String _locationInfo = "Retrieving location...";
  String _countryCode = "IN"; // Default country code
  bool _isLoadingLocation = true;
  bool _locationPermissionDenied = false;
  Timer? _refreshLocationTimer;

  // Emergency Data & Calling
  final Map<String, EmergencyData> _emergencyDatabase = {};
  final Map<String, Map<String, String>> _emergencyNumbers = {
    'US': {'general': '911', 'ambulance': '911'},
    'UK': {'general': '999', 'ambulance': '999', 'non_urgent': '111'},
    'IN': {'general': '112', 'ambulance': '108'},
    'AU': {'general': '000', 'ambulance': '000'},
    'CA': {'general': '911', 'ambulance': '911'},
    'DEFAULT': {'general': '112', 'ambulance': '108'},
  };
  String _activeEmergencyNumber = '112'; // Default based on India
  String _selectedEmergencyService = 'general';

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    // Start pulse timer for visual feedback
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() {});
    });

    _populateEmergencyDatabase();
    _getLocationAndNumbers();

    // Setup periodic location refresh
    _refreshLocationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _getLocationAndNumbers();
    });
  }

  void _populateEmergencyDatabase() {
    // HIGH PRIORITY EMERGENCIES
    _emergencyDatabase['heart_attack'] = EmergencyData(
      id: 'heart_attack',
      title: 'Heart Attack',
      icon: Icons.favorite,
      color: Colors.red,
      isHighPriority: true,
      description:
          'Signs include chest pain, shortness of breath, nausea, sweating.',
    );

    _emergencyDatabase['stroke'] = EmergencyData(
      id: 'stroke',
      title: 'Stroke',
      icon: Icons.psychology,
      color: Colors.deepOrange,
      isHighPriority: true,
      description:
          'Use FAST: Face drooping, Arm weakness, Speech difficulty, Time to call.',
    );

    _emergencyDatabase['severe_bleeding'] = EmergencyData(
      id: 'severe_bleeding',
      title: 'Severe Bleeding',
      icon: Icons.bloodtype,
      color: Colors.red.shade700,
      isHighPriority: true,
      description:
          'Apply direct pressure to the wound and call for help immediately.',
    );

    _emergencyDatabase['unconscious'] = EmergencyData(
      id: 'unconscious',
      title: 'Unconscious Person',
      icon: Icons.airline_seat_flat_angled,
      color: Colors.purple,
      isHighPriority: true,
      description:
          'Check for breathing. Place in recovery position if breathing.',
    );

    _emergencyDatabase['poisoning'] = EmergencyData(
      id: 'poisoning',
      title: 'Poisoning',
      icon: Icons.warning_rounded,
      color: Colors.deepPurple,
      isHighPriority: true,
      description:
          'Call poison control immediately. Dont induce vomiting unless instructed.',
    );

    _emergencyDatabase['burns'] = EmergencyData(
      id: 'burns',
      title: 'Severe Burns',
      icon: Icons.local_fire_department,
      color: Colors.orange.shade800,
      isHighPriority: true,
      description:
          'Cool with running water for 10-20 minutes. Dont use ice or creams.',
    );

    _emergencyDatabase['choking'] = EmergencyData(
      id: 'choking',
      title: 'Choking',
      icon: Icons.no_food,
      color: Colors.red.shade500,
      isHighPriority: true,
      description:
          'Perform abdominal thrusts (Heimlich maneuver) if person cannot breathe.',
    );

    _emergencyDatabase['anaphylaxis'] = EmergencyData(
      id: 'anaphylaxis',
      title: 'Severe Allergic Reaction',
      icon: Icons.coronavirus,
      color: Colors.red.shade600,
      isHighPriority: true,
      description:
          'Use epinephrine auto-injector if available. Call emergency services.',
    );

    // MEDIUM PRIORITY EMERGENCIES
    _emergencyDatabase['chest_pain'] = EmergencyData(
      id: 'chest_pain',
      title: 'Chest Pain',
      icon: Icons.monitor_heart,
      color: Colors.pink,
      isHighPriority: false,
      description:
          'Can be serious. Seek medical advice if severe or persistent.',
    );

    _emergencyDatabase['breathing'] = EmergencyData(
      id: 'breathing',
      title: 'Breathing Difficulty',
      icon: Icons.air,
      color: Colors.blue,
      isHighPriority: false,
      description:
          'Help person sit upright. Call emergency if severe or worsening.',
    );

    _emergencyDatabase['broken_bone'] = EmergencyData(
      id: 'broken_bone',
      title: 'Broken Bone',
      icon: Icons.healing,
      color: Colors.amber.shade700,
      isHighPriority: false,
      description:
          'Immobilize the injured area. Dont attempt to realign the bone.',
    );

    _emergencyDatabase['head_injury'] = EmergencyData(
      id: 'head_injury',
      title: 'Head Injury',
      icon: Icons.face,
      color: Colors.indigo,
      isHighPriority: false,
      description:
          'Monitor for confusion, vomiting, or loss of consciousness. Seek medical help.',
    );

    _emergencyDatabase['seizure'] = EmergencyData(
      id: 'seizure',
      title: 'Seizure',
      icon: Icons.electric_bolt,
      color: Colors.purple.shade700,
      isHighPriority: false,
      description:
          'Clear area of hazards. Time the seizure. Call emergency if longer than 5 minutes.',
    );

    _emergencyDatabase['minor_burns'] = EmergencyData(
      id: 'minor_burns',
      title: 'Minor Burns',
      icon: Icons.whatshot,
      color: Colors.orange,
      isHighPriority: false,
      description:
          'Cool with cold running water for 10-20 minutes. Cover with clean bandage.',
    );

    _emergencyDatabase['heat_exhaustion'] = EmergencyData(
      id: 'heat_exhaustion',
      title: 'Heat Exhaustion',
      icon: Icons.thermostat,
      color: Colors.orange.shade600,
      isHighPriority: false,
      description:
          'Move to cool place. Drink water. Seek help if symptoms worsen.',
    );

    _emergencyDatabase['frostbite'] = EmergencyData(
      id: 'frostbite',
      title: 'Frostbite',
      icon: Icons.ac_unit,
      color: Colors.lightBlue,
      isHighPriority: false,
      description:
          'Warm affected area gradually. Dont rub the area or use direct heat.',
    );

    _emergencyDatabase['sprain'] = EmergencyData(
      id: 'sprain',
      title: 'Sprain or Strain',
      icon: Icons.accessibility_new,
      color: Colors.green.shade700,
      isHighPriority: false,
      description:
          'Rest, ice, compression, and elevation. Seek medical help if severe.',
    );

    _emergencyDatabase['snake_bite'] = EmergencyData(
      id: 'snake_bite',
      title: 'Snake Bite',
      icon: Icons.pest_control,
      color: Colors.brown,
      isHighPriority: false,
      description:
          'Keep victim calm and immobile. Dont cut or suck the wound. Seek medical help.',
    );

    _emergencyDatabase['eye_injury'] = EmergencyData(
      id: 'eye_injury',
      title: 'Eye Injury',
      icon: Icons.visibility,
      color: Colors.cyan.shade700,
      isHighPriority: false,
      description:
          'Dont touch, rub, or apply pressure. Seek immediate medical attention.',
    );
  }

  // Combined function to get location and update numbers
  Future<void> _getLocationAndNumbers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _locationPermissionDenied = false;
    });
    try {
      final locationString = await _locationService.getCurrentLocation();
      if (!mounted) return;

      // Update state based on location string content
      if (locationString.contains("Location access denied")) {
        setState(() {
          _locationInfo = locationString;
          _isLoadingLocation = false;
          _locationPermissionDenied = true;
          _countryCode = "DEFAULT";
          _updateEmergencyNumbers();
        });
      } else if (locationString.startsWith("Unable") ||
          locationString.startsWith("Could not")) {
        setState(() {
          _locationInfo = locationString;
          _isLoadingLocation = false;
          _countryCode = "DEFAULT";
          _updateEmergencyNumbers();
        });
      } else {
        // Attempt to determine country code if location is valid
        final determinedCountryCode =
            await _determineCountryFromLocation(locationString);
        setState(() {
          _locationInfo = locationString;
          _isLoadingLocation = false;
          _countryCode = determinedCountryCode;
          _updateEmergencyNumbers();
        });
      }
    } catch (e) {
      debugPrint("Error in _getLocationAndNumbers: $e");
      if (mounted) {
        setState(() {
          _locationInfo = "Location Error";
          _isLoadingLocation = false;
          _countryCode = "DEFAULT";
          _updateEmergencyNumbers();
        });
      }
    }
  }

  // Simplified country determination
  Future<String> _determineCountryFromLocation(String location) async {
    String locLower = location.toLowerCase();
    if (locLower.contains("usa") || locLower.contains("united states"))
      return "US";
    if (locLower.contains("uk") || locLower.contains("united kingdom"))
      return "UK";
    if (locLower.contains("india")) return "IN";
    if (locLower.contains("australia")) return "AU";
    if (locLower.contains("canada")) return "CA";
    return "DEFAULT";
  }

  void _updateEmergencyNumbers() {
    Map<String, String> countryNumbers =
        _emergencyNumbers[_countryCode] ?? _emergencyNumbers["DEFAULT"]!;

    setState(() {
      _activeEmergencyNumber = countryNumbers[_selectedEmergencyService] ??
          countryNumbers["general"] ??
          "112";
    });
  }

  void _showDistressPersonDialog(String emergencyType) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Get AI First Response for:",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              _emergencyDatabase[emergencyType]?.title ?? 'Selected Emergency',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              "Who needs assistance?",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDistressPersonOption(
                    context: context,
                    title: "Me",
                    icon: Icons.person_outline,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAssessment(emergencyType, isSelf: true);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDistressPersonOption(
                    context: context,
                    title: "Someone Else",
                    icon: Icons.people_outline,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAssessment(emergencyType, isSelf: false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDistressPersonOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAssessment(String emergencyType, {required bool isSelf}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyAssessmentPage(
          emergencyType: emergencyType,
          isSelf: isSelf,
          locationInfo: _locationInfo,
        ),
      ),
    );
  }

  void _showEmergencyServiceDialog() {
    final Map<String, String> services =
        _emergencyNumbers[_countryCode] ?? _emergencyNumbers["DEFAULT"]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Emergency Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: services.entries.map((entry) {
              String serviceTitle = entry.key
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((word) =>
                      '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
                  .join(' ');

              return RadioListTile<String>(
                title: Text(serviceTitle),
                subtitle: Text(entry.value),
                value: entry.key,
                groupValue: _selectedEmergencyService,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedEmergencyService = value;
                      _updateEmergencyNumbers();
                    });
                    Navigator.pop(context);
                  }
                },
                secondary: _getEmergencyServiceIcon(entry.key),
                activeColor: Theme.of(context).colorScheme.primary,
                selected: _selectedEmergencyService == entry.key,
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Icon _getEmergencyServiceIcon(String serviceKey) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (serviceKey) {
      case 'general':
        return Icon(Icons.local_hospital_outlined, color: colorScheme.error);
      case 'ambulance':
        return Icon(Icons.emergency_outlined, color: Colors.green.shade600);
      case 'non_urgent':
        return Icon(Icons.medical_services_outlined,
            color: Colors.teal.shade600);
      default:
        return Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  Future<void> _callEmergency() async {
    HapticFeedback.heavyImpact();

    final Uri phoneUri = Uri(scheme: 'tel', path: _activeEmergencyNumber);

    // Check if the call can be launched *before* showing the dialog
    if (!await canLaunchUrl(phoneUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Cannot make calls from this device to $_activeEmergencyNumber'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.call_outlined, color: Colors.red.shade700),
              const SizedBox(width: 10),
              const Text('Confirm Emergency Call'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: <TextSpan>[
                    const TextSpan(
                        text: 'You are about to call the emergency number: '),
                    TextSpan(
                        text: _activeEmergencyNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const TextSpan(
                        text:
                            '.\n\nOnly proceed if this is a genuine emergency.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Current Location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_locationInfo.contains("denied") ||
                      _locationInfo.contains("Unable")
                  ? "Location unavailable - please state verbally."
                  : _locationInfo),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('CALL NOW'),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await launchUrl(phoneUri);
                } catch (e) {
                  debugPrint("Error launching call URL: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error launching call: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showMapLocation() async {
    HapticFeedback.lightImpact();
    try {
      final result = await _locationService.openLocationInMap();
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseTimer?.cancel();
    _refreshLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool flashState = (_pulseTimer?.tick ?? 0) % 2 == 0;
    String emergencyServiceName = _selectedEmergencyService
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Care'),
        elevation: 1.0,
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      drawer: const DrawerMenu(currentRoute: '/emergency'),
      body: Column(
        children: [
          // --- Top Emergency Call Bar ---
          _buildEmergencyCallBar(flashState, emergencyServiceName),

          // --- Emergency Situations List ---
          Expanded(
            child: _buildEmergencyList(),
          ),
        ],
      ),
    );
  }

  // Builds the top red bar for calling emergency services
  Widget _buildEmergencyCallBar(bool flashState, String serviceName) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            flashState
                ? theme.colorScheme.error.withOpacity(0.8)
                : theme.colorScheme.error,
            theme.colorScheme.error.withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
      child: Column(
        children: [
          // --- Row for Icon and Service Number ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated Emergency Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onError,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.error.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.call_outlined,
                    color: theme.colorScheme.error,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Service Name and Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown to change service type
                    InkWell(
                      onTap: _showEmergencyServiceDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              serviceName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onError,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down,
                                color:
                                    theme.colorScheme.onError.withOpacity(0.7),
                                size: 20),
                          ],
                        ),
                      ),
                    ),
                    // Emergency Number (Larger)
                    Text(
                      _activeEmergencyNumber,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onError,
                        letterSpacing: 1.5,
                        shadows: const [
                          Shadow(blurRadius: 1, color: Colors.black38)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // --- Call Button ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('CALL EMERGENCY SERVICES'),
              onPressed: _callEmergency,
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                backgroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- Location Info ---
          GestureDetector(
            onTap: _isLoadingLocation || _locationPermissionDenied
                ? null
                : _showMapLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onError.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _locationPermissionDenied
                        ? Icons.location_disabled_outlined
                        : Icons.location_on_outlined,
                    color: _locationPermissionDenied
                        ? Colors.orange.shade300
                        : theme.colorScheme.onError.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT LOCATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onError.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _isLoadingLocation
                              ? "Refreshing location..."
                              : _locationInfo,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onError,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingLocation)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.onError.withOpacity(0.7),
                          strokeWidth: 2),
                    )
                  else if (!_locationPermissionDenied)
                    Icon(Icons.map_outlined,
                        color: theme.colorScheme.onError.withOpacity(0.7),
                        size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyList() {
    final List<EmergencyData> emergencies = _emergencyDatabase.values.toList();
    emergencies.sort((a, b) {
      if (a.isHighPriority == b.isHighPriority) {
        return a.title.compareTo(b.title);
      }
      return a.isHighPriority ? -1 : 1;
    });

    // Group emergencies by priority
    final highPriority = emergencies.where((e) => e.isHighPriority).toList();
    final otherPriority = emergencies.where((e) => !e.isHighPriority).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      children: [
        if (highPriority.isNotEmpty) ...[
          _buildPriorityHeader(
              'CRITICAL EMERGENCIES', Theme.of(context).colorScheme.error),
          ...highPriority.map((emergency) => _buildEmergencyTile(emergency)),
        ],
        if (otherPriority.isNotEmpty) ...[
          SizedBox(height: highPriority.isNotEmpty ? 24 : 0),
          _buildPriorityHeader('OTHER COMMON SITUATIONS',
              Theme.of(context).colorScheme.secondary),
          ...otherPriority.map((emergency) => _buildEmergencyTile(emergency)),
        ],
      ],
    );
  }

  // Helper to build the header for priority sections
  Widget _buildPriorityHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // Builds a single tile for an emergency type
  Widget _buildEmergencyTile(EmergencyData emergency) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: emergency.isHighPriority ? 3 : 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: emergency.isHighPriority
            ? BorderSide(
                color: theme.colorScheme.error.withOpacity(0.3), width: 1)
            : BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => _showDistressPersonDialog(emergency.id),
        borderRadius: BorderRadius.circular(12),
        splashColor: emergency.color.withOpacity(0.1),
        hoverColor: emergency.color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: emergency.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emergency.icon,
                  color: emergency.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emergency.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: emergency.isHighPriority
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emergency.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
