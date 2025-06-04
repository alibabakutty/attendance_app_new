import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:attendance_app/screen/employee_master.dart';
import 'package:attendance_app/service/firebase_service.dart';
import 'package:flutter/material.dart';

class EmployeeProfiles extends StatefulWidget {
  const EmployeeProfiles({super.key});

  @override
  State<EmployeeProfiles> createState() => _EmployeeProfilesState();
}

class _EmployeeProfilesState extends State<EmployeeProfiles> {
  final FirebaseService _firebaseService = FirebaseService();
  List<EmployeeMasterData> _employeeData = [];
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
        _employeeData = data;
        _isLoading = false;
      });
      print("Fetched ${_employeeData.length} employees");
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching employees: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load employee data: $e')),
      );
    }
  }

  Widget _buildEmployeeCard(EmployeeMasterData employee) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          employee.employeeName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1), // dark blue
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "ID: ${employee.employeeId}",
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF0D47A1)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeMaster(
                mobileNumber: employee.mobileNumber,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // Soft light blue background
      appBar: AppBar(
        title: const Text('Employee Profiles'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employeeData.isEmpty
              ? const Center(
                  child: Text(
                    'No employees added yet',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchEmployees,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _employeeData.length,
                    itemBuilder: (context, index) =>
                        _buildEmployeeCard(_employeeData[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/employeeMaster');
        },
        backgroundColor: Colors.blueAccent,
        tooltip: 'Add Employee',
        child: const Icon(Icons.add),
      ),
    );
  }
}
