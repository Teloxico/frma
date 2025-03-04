import 'package:flutter/material.dart';
import '../models/pill_reminder.dart';
import '../notifications/notification_service.dart';
import '../main.dart'; // for flutterLocalNotificationsPlugin

class PillReminderScreen extends StatefulWidget {
  const PillReminderScreen({super.key});

  @override
  State<PillReminderScreen> createState() => _PillReminderScreenState();
}

class _PillReminderScreenState extends State<PillReminderScreen> {
  final List<PillReminder> _pillReminders = [];
  int _nextId = 1; // used to assign unique notification IDs

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pill Reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPillReminder,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _pillReminders.length,
        itemBuilder: (context, index) {
          final reminder = _pillReminders[index];
          return ListTile(
            title: Text(reminder.pillName),
            subtitle: Text('Time: ${reminder.reminderTime.format(context)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                // Cancel scheduled notification
                NotificationService.cancelNotification(
                  flutterLocalNotificationsPlugin,
                  reminder.id,
                );
                setState(() {
                  _pillReminders.removeAt(index);
                });
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _addPillReminder() async {
    final newReminder = await showDialog<PillReminder>(
      context: context,
      builder: (context) {
        return AddPillDialog(nextId: _nextId);
      },
    );

    if (newReminder != null) {
      setState(() {
        _pillReminders.add(newReminder);
        _nextId++;
      });

      // Schedule daily notification
      await NotificationService.scheduleDailyNotification(
        plugin: flutterLocalNotificationsPlugin,
        id: newReminder.id,
        title: 'Pill Reminder',
        body: 'Time to take ${newReminder.pillName}',
        hour: newReminder.reminderTime.hour,
        minutes: newReminder.reminderTime.minute,
      );
    }
  }
}

class AddPillDialog extends StatefulWidget {
  final int nextId;
  const AddPillDialog({super.key, required this.nextId});

  @override
  State<AddPillDialog> createState() => _AddPillDialogState();
}

class _AddPillDialogState extends State<AddPillDialog> {
  final TextEditingController _pillNameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Pill Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pillNameController,
            decoration: const InputDecoration(labelText: 'Pill Name'),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              const Text('Reminder Time: '),
              Text(_selectedTime.format(context)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: _pickTime,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveReminder, child: const Text('Add')),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveReminder() {
    final pillName = _pillNameController.text.trim();
    if (pillName.isEmpty) return;

    final newReminder = PillReminder(
      id: widget.nextId,
      pillName: pillName,
      reminderTime: _selectedTime,
    );
    Navigator.pop(context, newReminder);
  }
}
