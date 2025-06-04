import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/authentication/auth_provider.dart';

class AdminManageDashboard extends StatefulWidget {
  const AdminManageDashboard({super.key});

  @override
  State<AdminManageDashboard> createState() => _AdminManageDashboardState();
}

class _AdminManageDashboardState extends State<AdminManageDashboard> {
  // Sample attendance data
  final List<Map<String, dynamic>> _attendanceData = [
    {
      'id': '1',
      'name': 'John Doe',
      'email': 'john@example.com',
      'status': 'Present',
      'date': '2023-06-15',
      'time': '09:15 AM',
    },
    {
      'id': '2',
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'status': 'Absent',
      'date': '2023-06-15',
      'time': '--',
    },
    {
      'id': '3',
      'name': 'Robert Johnson',
      'email': 'robert@example.com',
      'status': 'Present',
      'date': '2023-06-15',
      'time': '08:45 AM',
    },
  ];

  void _updateAttendanceStatus(int index) {
    setState(() {
      _attendanceData[index]['status'] =
          _attendanceData[index]['status'] == 'Present' ? 'Absent' : 'Present';
      _attendanceData[index]['time'] =
          _attendanceData[index]['status'] == 'Present'
          ? TimeOfDay.now().format(context)
          : '--';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Non-admin access block
    if (!authProvider.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF273F4F),
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: const Color(0xFF273F4F),
          iconTheme: const IconThemeData(color: Colors.cyanAccent),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.cyanAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Administrator Access Required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'You need administrator privileges to access this section.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFFB0BEC5)),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Logic to redirect to login or home page
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Admin access content
    return Scaffold(
      backgroundColor: const Color(0xFF273F4F),
      appBar: AppBar(
        title: const Text('Attendance Management'),
        backgroundColor: const Color(0xFF273F4F),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh logic would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance records refreshed'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF37474F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.people_alt, color: Colors.cyanAccent),
                  SizedBox(width: 10),
                  Text(
                    'Employee Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Attendance List
            Expanded(
              child: ListView.builder(
                itemCount: _attendanceData.length,
                itemBuilder: (context, index) {
                  final record = _attendanceData[index];
                  return Card(
                    color: const Color(0xFF37474F),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                record['name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: record['status'] == 'Present'
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  record['status'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            record['email'],
                            style: const TextStyle(color: Color(0xFFB0BEC5)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFFB0BEC5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                record['date'],
                                style: const TextStyle(
                                  color: Color(0xFFB0BEC5),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: Color(0xFFB0BEC5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                record['time'],
                                style: const TextStyle(
                                  color: Color(0xFFB0BEC5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: record['status'] == 'Present'
                                    ? Colors.orange[800]
                                    : Colors.green[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _updateAttendanceStatus(index),
                              child: Text(
                                record['status'] == 'Present'
                                    ? 'Mark as Absent'
                                    : 'Mark as Present',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
