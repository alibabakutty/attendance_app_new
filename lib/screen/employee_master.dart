import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:attendance_app/service/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class EmployeeMaster extends StatefulWidget {
  const EmployeeMaster({super.key, this.mobileNumber});
  final String? mobileNumber;

  @override
  State<EmployeeMaster> createState() => _EmployeeMasterState();
}

class _EmployeeMasterState extends State<EmployeeMaster> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  Timestamp? _dateOfJoining;
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _aadhaarDisplayController =
      TextEditingController();
  final TextEditingController _panDisplayController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureAadhaar = true;
  bool _obscurePan = true;
  bool _isEditing = false;

  EmployeeMasterData? _employeeData;
  String? mobileNumberFromArgs;

  @override
  void initState() {
    super.initState();
    mobileNumberFromArgs = widget.mobileNumber;
    if (mobileNumberFromArgs != null) {
      _mobileNumberController.text = mobileNumberFromArgs!;
    }

    _aadhaarController.addListener(_updateAadhaarDisplay);
    _panController.addListener(_updatePanDisplay);

    _fetchEmployeeData();
  }

  void _updateAadhaarDisplay() {
    final text = _aadhaarController.text;
    if (_obscureAadhaar) {
      if (text.isEmpty) {
        _aadhaarDisplayController.text = '';
      } else if (text.length <= 4) {
        _aadhaarDisplayController.text = 'XXXX' + text.substring(text.length);
      } else if (text.length <= 8) {
        _aadhaarDisplayController.text = 'XXXX XXXX ' + text.substring(4);
      } else {
        _aadhaarDisplayController.text =
            'XXXX XXXX ' + text.substring(text.length - 4);
      }
    } else {
      // Format as XXXX XXXX XXXX when visible
      String formatted = '';
      for (int i = 0; i < text.length; i++) {
        if (i == 4 || i == 8) formatted += ' ';
        formatted += text[i];
      }
      _aadhaarDisplayController.text = formatted;
    }
  }

  void _updatePanDisplay() {
    final text = _panController.text;
    if (_obscurePan) {
      if (text.isEmpty) {
        _panDisplayController.text = '';
      } else if (text.length <= 5) {
        _panDisplayController.text = 'XXXXX' + text.substring(text.length);
      } else {
        _panDisplayController.text = 'XXXXX' + text.substring(5);
      }
    } else {
      _panDisplayController.text = text;
    }
  }

  Future<void> _fetchEmployeeData() async {
    if (mobileNumberFromArgs != null) {
      try {
        _employeeData = await _firebaseService
            .fetchEmployeeMasterDataByMobileNumber(mobileNumberFromArgs!);
        if (_employeeData != null) {
          setState(() {
            _employeeIdController.text = _employeeData!.employeeId;
            _nameController.text = _employeeData!.employeeName;
            _mobileNumberController.text = _employeeData!.mobileNumber;
            _dateOfJoining = _employeeData!.dateOfJoining;
            _aadhaarController.text = _employeeData!.aadhaarNumber;
            _panController.text = _employeeData!.panNumber;
            _emailController.text = _employeeData!.email;
            _passwordController.text = _employeeData!.password;
            _isEditing = true;

            _updateAadhaarDisplay();
            _updatePanDisplay();
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching employee data: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        if (_dateOfJoining == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a date of joining')),
          );
          return;
        }

        final employeeDataMap = {
          'employee_id': _employeeIdController.text.trim(),
          'employee_name': _nameController.text.trim(),
          'mobile_number': _mobileNumberController.text.trim(),
          'date_of_joining': _dateOfJoining!,
          'aadhaar_number': _aadhaarController.text.trim(),
          'pan_number': _panController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'updated_at': Timestamp.now(),
        };

        bool success;

        if (_isEditing) {
          success =
              await _firebaseService.updateEmployeeMasterDataByMobileNumber(
            _mobileNumberController.text.trim(),
            employeeDataMap,
          );
        } else {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          await authProvider.createAccount(
            username: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            employeeId: _employeeIdController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
            isAdmin: false,
          );

          final employeeMasterData = EmployeeMasterData(
            employeeId: _employeeIdController.text.trim(),
            employeeName: _nameController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
            dateOfJoining: _dateOfJoining!,
            aadhaarNumber: _aadhaarController.text.trim(),
            panNumber: _panController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            createdAt: Timestamp.now(),
          );

          success =
              await _firebaseService.addNewEmployeeData(employeeMasterData);
        }

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Employee updated successfully!'
                    : 'Employee added successfully!',
              ),
            ),
          );
          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Operation failed. Please try again.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _aadhaarDisplayController.dispose();
    _panDisplayController.dispose();
    _employeeIdController.dispose();
    _nameController.dispose();
    _mobileNumberController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfJoining = Timestamp.fromDate(picked);
      });
    }
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
              children: [
                // Employee ID Field
                TextFormField(
                  controller: _employeeIdController,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter employee ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Employee Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Employee Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter employee name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mobile Number Field
                TextFormField(
                  controller: _mobileNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    hintText: '10-digit mobile number',
                    prefixText: '+91 ',
                  ),
                  maxLength: 10,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter mobile number';
                    }
                    if (value.length != 10) {
                      return 'Mobile number must be 10 digits';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                      return 'Only numbers are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date of Joining Field
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Joining',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dateOfJoining == null
                              ? 'Select date'
                              : DateFormat('dd/MM/yyyy')
                                  .format(_dateOfJoining!.toDate()),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Aadhaar Number Field
                TextFormField(
                  controller: _aadhaarDisplayController,
                  decoration: InputDecoration(
                    labelText: 'Aadhaar Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.credit_card),
                    hintText: 'XXXX XXXX XXXX',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureAadhaar
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscureAadhaar = !_obscureAadhaar;
                          _updateAadhaarDisplay();
                        });
                      },
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 14, // 12 digits + 2 spaces
                  validator: (value) {
                    final actualValue = _aadhaarController.text;
                    if (actualValue.isEmpty)
                      return 'Please enter Aadhaar number';
                    if (actualValue.length < 12)
                      return 'Aadhaar must be 12 digits';
                    return null;
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  onChanged: (value) {
                    // Remove spaces and update the actual controller
                    final cleanedValue = value.replaceAll(' ', '');
                    if (cleanedValue != _aadhaarController.text) {
                      _aadhaarController.text = cleanedValue;
                      _aadhaarController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _aadhaarController.text.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // PAN Number Field
                TextFormField(
                  controller: _panDisplayController,
                  decoration: InputDecoration(
                    labelText: 'PAN Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.credit_card),
                    hintText: 'ABCDE1234F',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePan
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePan = !_obscurePan;
                          _updatePanDisplay();
                        });
                      },
                    ),
                  ),
                  maxLength: 10,
                  validator: (value) {
                    final actualValue = _panController.text;
                    if (actualValue.isEmpty) return 'Please enter PAN number';
                    if (actualValue.length < 10)
                      return 'PAN must be 10 characters';
                    return null;
                  },
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (value) {
                    if (value != _panController.text) {
                      _panController.text = value;
                      _panController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _panController.text.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                    hintText: 'employee@company.com',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    hintText: 'At least 6 characters',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Text(
                          _isEditing ? 'Update Employee' : 'Save Employee',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
