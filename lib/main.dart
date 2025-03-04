import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/pill_reminder_screen.dart';
import 'screens/settings_screen.dart';
import 'notifications/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications
  await NotificationService.initialize(flutterLocalNotificationsPlugin);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Chatbot',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      routes: {
        '/chat': (context) => const ChatScreen(),
        '/pillReminder': (context) => const PillReminderScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
