// lib/pages/appointments_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../widgets/drawer_menu.dart';

// Model for medical appointments
class Appointment {
  final int id;
  final String doctorName;
  final String specialty;
  final DateTime dateTime;
  final String location;
  final String notes;
  bool isCompleted;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.dateTime,
    required this.location,
    this.notes = '',
    this.isCompleted = false,
  });

  // Check if appointment is upcoming (within the next 24 hours)
  bool get isUpcoming {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    return !isCompleted &&
        difference.isNegative == false &&
        difference.inHours <= 24;
  }

  // Check if appointment is past due
  bool get isPastDue {
    return !isCompleted && dateTime.isBefore(DateTime.now());
  }
}

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({Key? key}) : super(key: key);

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage>
    with SingleTickerProviderStateMixin {
  // In a real app, these would come from a database or API
  final List<Appointment> _appointments = [];
  int _nextId = 0;

  // Tab controller for different appointment views
  late TabController _tabController;

  // Selected date for new appointments
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Controllers for form fields
  final _doctorController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Add some sample appointments for demo purposes
    if (_appointments.isEmpty) {
      _addSampleAppointments();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _doctorController.dispose();
    _specialtyController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Add sample appointments for demo
  void _addSampleAppointments() {
    // Sample upcoming appointment
    _appointments.add(
      Appointment(
        id: _nextId++,
        doctorName: 'Dr. Sarah Johnson',
        specialty: 'Cardiologist',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        location: 'Heart Health Clinic, 123 Medical Blvd',
        notes: 'Bring recent test results and medication list',
      ),
    );

    // Sample past appointment
    final pastDate = DateTime.now().subtract(const Duration(days: 14));
    _appointments.add(
      Appointment(
        id: _nextId++,
        doctorName: 'Dr. Michael Chen',
        specialty: 'Primary Care',
        dateTime: pastDate,
        location: 'Community Health Center',
        notes: 'Annual physical examination',
        isCompleted: true,
      ),
    );
  }

  // Add a new appointment
  void _addAppointment({
    required String doctorName,
    required String specialty,
    required DateTime dateTime,
    required String location,
    String notes = '',
  }) {
    setState(() {
      _appointments.add(
        Appointment(
          id: _nextId++,
          doctorName: doctorName,
          specialty: specialty,
          dateTime: dateTime,
          location: location,
          notes: notes,
        ),
      );

      // Sort appointments by date
      _appointments.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });
  }

  // Delete an appointment
  void _deleteAppointment(int id) {
    setState(() {
      _appointments.removeWhere((appointment) => appointment.id == id);
    });
  }

  // Mark appointment as completed
  void _toggleAppointmentStatus(int id) {
    setState(() {
      final index =
          _appointments.indexWhere((appointment) => appointment.id == id);
      if (index != -1) {
        _appointments[index].isCompleted = !_appointments[index].isCompleted;
      }
    });
  }

  // Show dialog to add a new appointment
  void _showAddAppointmentDialog() {
    // Reset form fields
    _doctorController.clear();
    _specialtyController.clear();
    _locationController.clear();
    _notesController.clear();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor name field
                TextField(
                  controller: _doctorController,
                  decoration: const InputDecoration(
                    labelText: 'Doctor Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

                const SizedBox(height: 16),

                // Specialty field
                TextField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                ),

                const SizedBox(height: 16),

                // Date picker
                InkWell(
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Time picker
                InkWell(
                  onTap: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _selectedTime = pickedTime;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      _selectedTime.format(context),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Location field
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),

                const SizedBox(height: 16),

                // Notes field
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate required fields
                if (_doctorController.text.isEmpty ||
                    _specialtyController.text.isEmpty ||
                    _locationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                    ),
                  );
                  return;
                }

                // Combine date and time
                final DateTime appointmentDateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );

                // Add appointment
                _addAppointment(
                  doctorName: _doctorController.text,
                  specialty: _specialtyController.text,
                  dateTime: appointmentDateTime,
                  location: _locationController.text,
                  notes: _notesController.text,
                );

                Navigator.pop(context);

                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appointment added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        elevation: 2.0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      drawer: const DrawerMenu(currentRoute: '/appointments'),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Upcoming appointments tab
          _buildAppointmentsList(
            _appointments
                .where((appointment) =>
                    !appointment.isCompleted &&
                    appointment.dateTime.isAfter(
                        DateTime.now().subtract(const Duration(days: 1))))
                .toList(),
            emptyMessage: 'No upcoming appointments',
          ),

          // Completed appointments tab
          _buildAppointmentsList(
            _appointments
                .where((appointment) => appointment.isCompleted)
                .toList(),
            emptyMessage: 'No completed appointments',
          ),

          // All appointments tab
          _buildAppointmentsList(
            _appointments,
            emptyMessage: 'No appointments',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAppointmentDialog,
        tooltip: 'Add Appointment',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Build the list of appointments
  Widget _buildAppointmentsList(List<Appointment> appointments,
      {required String emptyMessage}) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to add an appointment',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddAppointmentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Appointment'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: appointment.isUpcoming
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: Dismissible(
            key: Key('appointment_${appointment.id}'),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              _deleteAppointment(appointment.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Appointment with ${appointment.doctorName} deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // Re-add the appointment
                      setState(() {
                        appointments.insert(index, appointment);
                      });
                    },
                  ),
                ),
              );
            },
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: appointment.isCompleted
                    ? Colors.green
                    : appointment.isPastDue
                        ? Colors.red
                        : appointment.isUpcoming
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                child: Icon(
                  appointment.isCompleted ? Icons.check : Icons.calendar_month,
                  color: Colors.white,
                ),
              ),
              title: Text(
                appointment.doctorName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: appointment.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(appointment.specialty),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(DateFormat('E, MMM d, yyyy • h:mm a')
                          .format(appointment.dateTime)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(appointment.location)),
                    ],
                  ),
                  if (appointment.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text(appointment.notes)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                  appointment.isCompleted
                      ? Icons.refresh
                      : Icons.check_circle_outline,
                  color: appointment.isCompleted ? Colors.green : Colors.grey,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _toggleAppointmentStatus(appointment.id);
                },
                tooltip: appointment.isCompleted
                    ? 'Mark as not completed'
                    : 'Mark as completed',
              ),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }
}
