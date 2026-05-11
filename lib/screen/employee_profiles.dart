import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:attendance_app/screen/employee_master.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:attendance_app/service/employee_api_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/authentication/auth_provider.dart';

class EmployeeProfiles extends StatefulWidget {
  const EmployeeProfiles({super.key});

  @override
  State<EmployeeProfiles> createState() => _EmployeeProfilesState();
}

class _EmployeeProfilesState extends State<EmployeeProfiles> {
  final EmployeeApiService _employeeApiService = EmployeeApiService();
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
      final data = await _employeeApiService.getAllEmployees();

      setState(() {
        _employeeData = data;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load employees: $e',
          ),
        ),
      );
    }
  }

  Future<void> _uploadExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);

      final authProvider = Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading employees...'),
        ),
      );

      final success = await _employeeApiService.bulkUploadEmployees(
        file,
        authProvider.token!,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Bulk employee upload successful',
            ),
          ),
        );

        _fetchEmployees();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Bulk upload failed',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Error: $e',
          ),
        ),
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
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blueAccent,
          backgroundImage: employee.employeeImageData != null &&
                  employee.employeeImageData!.isNotEmpty
              ? MemoryImage(
                  base64Decode(
                    employee.employeeImageData!,
                  ),
                )
              : null,
          child: employee.employeeImageData == null ||
                  employee.employeeImageData!.isEmpty
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
                )
              : null,
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
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeMaster(
                mobileNumber: employee.mobileNumber,
              ),
            ),
          );

          _fetchEmployees();
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
        actions: [
          IconButton(
              tooltip: 'Import Excel',
              onPressed: _uploadExcel,
              icon: const Icon(Icons.upload_file))
        ],
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
        onPressed: () async {
          await Navigator.pushNamed(context, '/employeeMaster');
          _fetchEmployees();
        },
        backgroundColor: Colors.blueAccent,
        tooltip: 'Add Employee',
        child: const Icon(Icons.add),
      ),
    );
  }
}
