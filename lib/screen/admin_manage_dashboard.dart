import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:attendance_app/screen/update_mark_attendance.dart';
import 'package:attendance_app/service/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminManageDashboard extends StatefulWidget {
  const AdminManageDashboard({super.key});

  @override
  State<AdminManageDashboard> createState() => _AdminManageDashboardState();
}

class _AdminManageDashboardState extends State<AdminManageDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  List<EmployeeMasterData> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final data = await _firebaseService.getAllEmployeeMasterData();
      setState(() {
        _employees = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load employees: $e')));
    }
  }

  Future<MarkAttendanceData?> _fetchEmployeeAttendance(
    String mobileNumber,
    DateTime date,
  ) async {
    try {
      return await _firebaseService
          .fetchAttendanceByMobileNumberWithSpecificDate(mobileNumber, date);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching attendance: $e')));
      return null;
    }
  }

  void _showEmployeeDetails(EmployeeMasterData employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF37474F),
        title: Text(
          employee.employeeName,
          style: const TextStyle(color: Colors.cyanAccent),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Employee ID', employee.employeeId),
              _buildDetailRow('Email', employee.email),
              _buildDetailRow('Mobile', employee.mobileNumber),
              _buildDetailRow('Aadhaar', employee.aadhaarNumber),
              _buildDetailRow('PAN', employee.panNumber),
              _buildDetailRow(
                'Date of Joining',
                employee.dateOfJoining.toDate().toString().split(' ')[0],
              ),
              _buildDetailRow(
                'Account Created',
                employee.createdAt.toDate().toString().split(' ')[0],
              ),
              FutureBuilder<MarkAttendanceData?>(
                future: _fetchEmployeeAttendance(
                  employee.mobileNumber,
                  DateTime.now(),
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasData && snapshot.data != null) {
                    final attendance = snapshot.data!;
                    return _buildDetailRow(
                      'Today\'s Status',
                      attendance.officeTimeIn != null ? 'Present' : 'Absent',
                    );
                  }
                  return _buildDetailRow('Today\'s Status', 'Not marked');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAdmin) {
      return _buildNonAdminView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF273F4F),
      appBar: AppBar(
        title: const Text(
          'Admin Control Panel',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF273F4F),
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmployees,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? _buildEmptyState()
              : _buildEmployeeList(),
    );
  }

  Widget _buildNonAdminView() {
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
                onPressed: () => Navigator.pop(context),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No Employees Found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _fetchEmployees,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            color: const Color(0xFF37474F),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Employees',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _employees.length.toString(),
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(51, 0, 255, 255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_alt,
                      color: Colors.cyanAccent,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final employee = _employees[index];
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
                              employee.employeeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              employee.employeeId,
                              style: const TextStyle(color: Colors.cyanAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          employee.email,
                          style: const TextStyle(color: Color(0xFFB0BEC5)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 16,
                              color: Color(0xFFB0BEC5),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              employee.mobileNumber,
                              style: const TextStyle(color: Color(0xFFB0BEC5)),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Color(0xFFB0BEC5),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              employee.dateOfJoining.toDate().toString().split(
                                    ' ',
                                  )[0],
                              style: const TextStyle(color: Color(0xFFB0BEC5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<MarkAttendanceData?>(
                          future: _fetchEmployeeAttendance(
                            employee.mobileNumber,
                            DateTime.now(),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Present today',
                                    style: TextStyle(color: Colors.green[200]),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Absent today',
                                  style: TextStyle(color: Colors.red[200]),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _showEmployeeDetails(employee),
                                child: const Text(
                                  'View Details',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  final today = DateTime.now();
                                  final attendance =
                                      await _fetchEmployeeAttendance(
                                    employee.mobileNumber,
                                    today,
                                  );

                                  if (!mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          UpdateMarkAttendance(
                                        mobileNumberArgs: employee.mobileNumber,
                                        existingAttendance: attendance,
                                        employeeName: employee.employeeName,
                                        employeeId: employee.employeeId,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Update Attendance',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
