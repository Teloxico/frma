// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:io' show Platform; // <--- IMPORT ADDED HERE for Platform checks

// Import Pages for Routing
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/profile_page.dart';
import 'pages/chat_page.dart';
import 'pages/health_metrics_page.dart';
import 'pages/med_reminder_page.dart';
import 'pages/appointments_page.dart';
import 'pages/emergency_care_page.dart';
// Import Providers and Services
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background notification tap
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone and Notification Initialization
  await _configureLocalTimeZone();
  await _initializeNotifications();

  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  final prefs = await SharedPreferences.getInstance();
  await ApiService().initialize(); // Ensure API service is initialized

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(prefs)),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _configureLocalTimeZone() async {
  // Configure local timezone settings
  tz_data.initializeTimeZones();
  try {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
  } catch (e) {
    debugPrint("Error configuring timezone: $e");
  }
}

Future<void> _initializeNotifications() async {
  // Initialize notification settings for Android and iOS
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground);

    // Request permissions after initialization, avoiding web platform
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        // Check if running on Android
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
        // Consider requesting exact alarm permission if needed for precise reminders
        // await androidImplementation?.requestExactAlarmsPermission();
      } else if (Platform.isIOS) {
        // Check if running on iOS
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    }
  } catch (e) {
    debugPrint("Error initializing notifications: $e");
  }
}

void onNotificationTap(NotificationResponse notificationResponse) {
  // Handle notification tap when the app is in the foreground
  debugPrint('Notification tapped: ${notificationResponse.payload}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // Build the main application widget
    return MaterialApp(
      title: 'Health Assistant',
      debugShowCheckedModeBanner: false, // Hide debug banner
      themeMode: themeProvider.themeMode,
      // Define light theme settings
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: settingsProvider.primaryColor,
          secondary: settingsProvider.primaryColor
              .withAlpha(178), // Slightly transparent secondary
        ),
        fontFamily: 'Roboto', // Example font family
      ),
      // Define dark theme settings
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: settingsProvider.primaryColor,
          secondary: settingsProvider.primaryColor.withAlpha(178),
          surface: const Color(0xFF1E1E1E), // Custom dark surface
        ),
        cardTheme:
            const CardTheme(color: Color(0xFF2C2C2C)), // Custom dark card color
        fontFamily: 'Roboto',
      ),
      initialRoute: '/home', // Set the initial route
      // Define named routes for navigation
      routes: {
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
        '/profile': (context) => const ProfilePage(),
        '/chat': (context) => const ChatPage(),
        '/health_metrics': (context) => const HealthMetricsPage(),
        '/medications': (context) => const MedicationReminderPage(),
        '/appointments': (context) => const AppointmentsPage(),
        '/emergency': (context) => const EmergencyCarePage(),
      },
    );
  }
}
