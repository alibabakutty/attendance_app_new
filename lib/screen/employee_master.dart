import 'dart:io';
import 'dart:convert';
import 'package:attendance_app/authentication/auth_service.dart';
import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:attendance_app/service/employee_api_service.dart';

class EmployeeMaster extends StatefulWidget {
  const EmployeeMaster({super.key, this.mobileNumber});
  final String? mobileNumber;

  @override
  State<EmployeeMaster> createState() => _EmployeeMasterState();
}

class _EmployeeMasterState extends State<EmployeeMaster> {
  final EmployeeApiService _employeeApiService = EmployeeApiService();
  final _formKey = GlobalKey<FormState>();

  DateTime? _dateOfJoining;
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Dynamic state list containing nested multi-site scopes
  List<EmployeeLocationData> _allocatedLocations = [];

  File? _selectedImage;
  String? _employeeImageData;
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureAadhaar = true;
  bool _obscurePan = true;
  bool _isEditing = false;
  EmployeeMasterData? _employeeData;

  @override
  void initState() {
    super.initState();
    if (widget.mobileNumber != null) {
      _mobileNumberController.text = widget.mobileNumber!;
    }
    _fetchEmployeeData();
  }

  Future<void> _fetchEmployeeData() async {
    if (widget.mobileNumber != null) {
      try {
        final token = await AuthService.getToken();
        if (token == null) return;

        final employeeData =
            await _employeeApiService.getEmployeeByMobileNumber(
          widget.mobileNumber!,
          token,
        );

        if (employeeData != null && mounted) {
          setState(() {
            _employeeData = employeeData;
            _employeeIdController.text = employeeData.employeeId;
            _nameController.text = employeeData.employeeName;
            _mobileNumberController.text = employeeData.mobileNumber;
            _dateOfJoining = employeeData.dateOfJoining;
            _aadhaarController.text = employeeData.aadhaarNumber;
            _panController.text = employeeData.panNumber;
            _emailController.text = employeeData.email;
            _passwordController.text = employeeData.password;
            _employeeImageData = employeeData.employeeImageData;
            _allocatedLocations = List.from(employeeData.locations);
            _isEditing = true;
          });
        }
      } catch (e) {
        _showSnackBar('Error fetching employee data: $e');
      }
    }
  }

  void _addNewLocationScope() {
    final siteController = TextEditingController();
    final inLatController = TextEditingController();
    final inLonController = TextEditingController();
    final outLatController = TextEditingController();
    final outLonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Assigned Office Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: siteController,
                  decoration: const InputDecoration(labelText: 'Site Name')),
              TextField(
                  controller: inLatController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Check-In Latitude')),
              TextField(
                  controller: inLonController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Check-In Longitude')),
              TextField(
                  controller: outLatController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Check-Out Latitude')),
              TextField(
                  controller: outLonController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Check-Out Longitude')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (siteController.text.isNotEmpty &&
                  inLatController.text.isNotEmpty &&
                  inLonController.text.isNotEmpty) {
                setState(() {
                  _allocatedLocations.add(
                    EmployeeLocationData(
                      siteName: siteController.text.trim(),
                      officeTimeInLocation: GeoPointData(
                        latitude: double.parse(inLatController.text.trim()),
                        longitude: double.parse(inLonController.text.trim()),
                      ),
                      officeTimeOutLocation: GeoPointData(
                        latitude: double.parse(outLatController.text.trim()),
                        longitude: double.parse(outLonController.text.trim()),
                      ),
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add Location'),
          )
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfJoining == null) {
      _showSnackBar('Please select date of joining');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? base64Image = _employeeImageData;
      if (_selectedImage != null) {
        final imageBytes = await _selectedImage!.readAsBytes();
        base64Image = base64Encode(imageBytes);
      }

      final employeeData = EmployeeMasterData(
        employeeId: _employeeIdController.text.trim(),
        employeeName: _nameController.text.trim(),
        mobileNumber: _mobileNumberController.text.trim(),
        dateOfJoining: _dateOfJoining,
        aadhaarNumber: _aadhaarController.text.trim(),
        panNumber: _panController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        createdAt: _isEditing ? _employeeData?.createdAt : DateTime.now(),
        employeeImageData: base64Image,
        locations: _allocatedLocations,
      );

      final token = await AuthService.getToken();
      if (token == null)
        throw Exception("Session Authentication Token Expired");

      bool success = _isEditing
          ? await _employeeApiService.updateEmployee(
              _mobileNumberController.text.trim(), employeeData, token)
          : await _employeeApiService.createEmployee(employeeData, token);

      if (success && mounted) {
        _showSnackBar(_isEditing
            ? 'Employee updated successfully'
            : 'Employee saved successfully');
        Navigator.pop(context);
      } else {
        _showSnackBar('Operation database rejected submission');
      }
    } catch (e) {
      _showSnackBar('Error execution failure: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfJoining ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfJoining = picked);
    }
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    _mobileNumberController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee Details' : 'Add New Employee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitForm,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_employeeImageData != null &&
                                  _employeeImageData!.isNotEmpty)
                              ? MemoryImage(base64Decode(_employeeImageData!))
                              : null,
                      child: _selectedImage == null &&
                              (_employeeImageData == null ||
                                  _employeeImageData!.isEmpty)
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _employeeIdController,
                  decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge)),
                  validator: (v) => v!.isEmpty ? 'Enter employee ID' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Employee Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'Enter employee name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileNumberController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      prefixText: '+91 '),
                  validator: (v) => v!.length != 10
                      ? 'Mobile number must be 10 digits'
                      : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Date of Joining',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_dateOfJoining == null
                            ? 'Select date'
                            : DateFormat('dd/MM/yyyy').format(_dateOfJoining!)),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aadhaarController,
                  obscureText: _obscureAadhaar,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: 'Aadhaar Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.credit_card),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureAadhaar
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureAadhaar = !_obscureAadhaar),
                    ),
                  ),
                  validator: (v) =>
                      v!.length < 12 ? 'Aadhaar must be 12 digits' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _panController,
                  obscureText: _obscurePan,
                  maxLength: 10,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))
                  ],
                  decoration: InputDecoration(
                    labelText: 'PAN Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.credit_card),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePan
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePan = !_obscurePan),
                    ),
                  ),
                  validator: (v) =>
                      v!.length < 10 ? 'PAN must be 10 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email)),
                  validator: (v) =>
                      !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
                          ? 'Enter valid email'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v!.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),

                // --- SUB-COLLECTION LOCATIONS SECTION ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Assigned Work Sites (${_allocatedLocations.length})",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                        onPressed: _addNewLocationScope,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text("Add Site")),
                  ],
                ),
                const Divider(),
                _allocatedLocations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("No location scopes assigned yet.",
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _allocatedLocations.length,
                        itemBuilder: (context, index) {
                          final loc = _allocatedLocations[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.location_on,
                                  color: Colors.blue),
                              title: Text(loc.siteName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "In: ${loc.officeTimeInLocation.latitude}, ${loc.officeTimeInLocation.longitude}\nOut: ${loc.officeTimeOutLocation.latitude}, ${loc.officeTimeOutLocation.longitude}"),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setState(
                                    () => _allocatedLocations.removeAt(index)),
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blue),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEditing ? 'Update Employee' : 'Save Employee',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Paste this at the absolute bottom of your file
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
