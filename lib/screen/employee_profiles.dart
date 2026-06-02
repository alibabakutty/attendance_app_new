import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:attendance_app/screen/employee_master.dart';
import 'package:attendance_app/service/employee_api_service.dart';
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
    // Fetch data safely after context components finish rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmployees();
    });
  }

  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Pulling active authentication token out of Provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        throw Exception("Authentication token is missing. Please re-login.");
      }

      // Updated to match the refined service method parameter requirements
      final data = await _employeeApiService.getAllEmployees(token);

      // Simple case-insensitive A to Z alphabetical sorting
      data.sort((a, b) =>
          a.employeeName.toLowerCase().compareTo(b.employeeName.toLowerCase()));

      if (mounted) {
        setState(() {
          _employeeData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Failed to load employees: $e'),
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

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token == null) {
        throw Exception("Authentication token missing.");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading employee spreadsheet...')),
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
            content: Text('Bulk employee upload successful'),
          ),
        );
        _fetchEmployees();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Bulk upload failed. Verify data format structures.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Upload exception: $e'),
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
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blueAccent,
            backgroundImage: employee.employeeImageData != null &&
                    employee.employeeImageData!.isNotEmpty
                ? MemoryImage(base64Decode(employee.employeeImageData!))
                : null,
            child: employee.employeeImageData == null ||
                    employee.employeeImageData!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 28)
                : null,
          ),
          title: Text(
            employee.employeeName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              fontSize: 18,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                "ID: ${employee.employeeId}",
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              // --- LOCATION BADGE INTEGRATION ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: employee.locations.isEmpty
                      ? Colors.amber.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  employee.locations.isEmpty
                      ? "No working sites assigned"
                      : "Assigned Sites: ${employee.locations.length}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: employee.locations.isEmpty
                        ? Colors.amber.shade900
                        : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Color(0xFF0D47A1),
            size: 18,
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeMaster(
                  mobileNumber: employee.mobileNumber,
                ),
              ),
            );
            // Refresh list context when returning back from editing view profiles
            _fetchEmployees();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('Employee Profiles'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Import Excel Sheet',
            onPressed: _uploadExcel,
            icon: const Icon(Icons.upload_file),
          )
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
          // Explicit Material Route navigation used for safety over unmapped string properties
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EmployeeMaster()),
          );
          _fetchEmployees();
        },
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        tooltip: 'Add Employee',
        child: const Icon(Icons.add),
      ),
    );
  }
}
