import 'dart:convert';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class MarkAttendance extends StatefulWidget {
  const MarkAttendance({super.key});

  @override
  State<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> {
  DateTime? _officeTimeIn;
  DateTime? _officeTimeOut;

  bool _isSubmitted = false;
  bool _isLoading = true;
  bool _isSaving = false;

  List<String> _siteNames = [];
  String? _selectedSite;
  String? employeeImageData;

  @override
  void initState() {
    super.initState();

    _fetchTodayAttendance();
    _fetchSiteNames();
  }

  // =========================
  // FETCH TODAY ATTENDANCE
  // =========================

  Future<void> _fetchTodayAttendance() async {
    try {
      final authProvider = Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      final response = await http.get(
        Uri.parse(
          'http://192.168.1.2:8080/api/v1/attendance/today/${authProvider.username}',
        ),
        headers: authProvider.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _officeTimeIn = data['officeTimeIn'] != null
              ? DateTime.parse(
                  data['officeTimeIn'],
                )
              : null;

          _officeTimeOut = data['officeTimeOut'] != null
              ? DateTime.parse(
                  data['officeTimeOut'],
                )
              : null;

          _selectedSite = data['siteName'];

          _isSubmitted = _officeTimeOut != null;
        });
      }
    } catch (e) {
      debugPrint(
        'Fetch Attendance Error: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================
  // FETCH SITE NAMES
  // =========================

  Future<void> _fetchSiteNames() async {
    try {
      final authProvider = Provider.of<AuthProvider>(
        context,
        listen: false,
      );

      final response = await http.get(
        Uri.parse(
          'http://192.168.1.2:8080/api/v1/site-name-masters',
        ),
        headers: authProvider.authHeaders,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          _siteNames = data
              .map<String>(
                (e) => e['siteName'].toString(),
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint(
        'Site Fetch Error: $e',
      );
    }
  }

  // =========================
  // TIME VALIDATION
  // =========================

  bool _isWithinOfficeTimeInRange(
    DateTime time,
  ) {
    final authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    final start = DateTime(
      time.year,
      time.month,
      time.day,
      9,
      0,
    );

    final end = authProvider.isAdmin
        ? DateTime(
            time.year,
            time.month,
            time.day,
            10,
            30,
          )
        : DateTime(
            time.year,
            time.month,
            time.day,
            9,
            45,
          );

    return time.isAfter(
          start.subtract(
            const Duration(
              seconds: 1,
            ),
          ),
        ) &&
        time.isBefore(
          end.add(
            const Duration(
              seconds: 1,
            ),
          ),
        );
  }

  bool _isWithinOfficeTimeOutRange(
    DateTime time,
  ) {
    final start = DateTime(
      time.year,
      time.month,
      time.day,
      18,
      30,
    );

    final end = DateTime(
      time.year,
      time.month,
      time.day,
      19,
      15,
    );

    return time.isAfter(
          start.subtract(
            const Duration(
              seconds: 1,
            ),
          ),
        ) &&
        time.isBefore(
          end.add(
            const Duration(
              seconds: 1,
            ),
          ),
        );
  }

  // =========================
  // MARK ATTENDANCE
  // =========================

  Future<void> _handleAction(
    String actionType,
  ) async {
    if (_isSaving) return;

    final authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    final now = DateTime.now();

    if (actionType == 'officeIn' && _selectedSite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Please select site',
          ),
        ),
      );

      return;
    }

    bool isValid = true;

    if (actionType == 'officeIn') {
      isValid = _isWithinOfficeTimeInRange(
        now,
      );
    }

    if (actionType == 'officeOut') {
      isValid = _isWithinOfficeTimeOutRange(
        now,
      );
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Outside allowed time range',
          ),
        ),
      );
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final body = {
        "employeeName": authProvider.username,
        "siteName": _selectedSite,
        "actionType": actionType,
      };

      final response = await http.post(
        Uri.parse(
          'http://192.168.1.2:8080/api/v1/attendance/mark',
        ),
        headers: authProvider.authHeaders,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          if (actionType == 'officeIn') {
            _officeTimeIn = now;
          }

          if (actionType == 'officeOut') {
            _officeTimeOut = now;
            _isSubmitted = true;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '$actionType marked successfully',
            ),
          ),
        );
      } else {
        throw Exception(
          response.body,
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
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // =========================
  // BUTTON ENABLE
  // =========================

  bool _shouldEnableButton(
    String actionType,
  ) {
    if (_isSubmitted) {
      return false;
    }

    switch (actionType) {
      case 'officeIn':
        return _officeTimeIn == null;

      case 'officeOut':
        return _officeTimeIn != null && _officeTimeOut == null;

      default:
        return false;
    }
  }

  // =========================
  // STATUS
  // =========================

  String _getStatusForCard(
    String actionType,
  ) {
    if (_officeTimeOut != null) {
      return 'Completed';
    }

    if (_officeTimeIn == null) {
      return actionType == 'officeIn' ? 'Absent' : '';
    }

    if (actionType == 'officeIn' && _officeTimeIn != null) {
      return 'Present';
    }

    return '';
  }

  Color _getStatusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'absent':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(
      context,
    );

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[800],
          title: const Text(
            'Mark Attendance',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: 16,
              ),
              child: Center(
                child: Text(
                  authProvider.username ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    children: [
                      // EMPLOYEE IMAGE
                      if (authProvider.employeeImageData != null &&
                          authProvider.employeeImageData!.isNotEmpty)
                        CircleAvatar(
                          radius: 45,
                          backgroundImage: MemoryImage(
                            base64Decode(
                              authProvider.employeeImageData!,
                            ),
                          ),
                        )
                      else
                        const CircleAvatar(
                          radius: 45,
                          child: Icon(
                            Icons.person,
                            size: 40,
                          ),
                        ),

                      const SizedBox(height: 12),

                      // USERNAME BELOW IMAGE (optional)
                      Text(
                        DateFormat(
                          'EEEE, MMM d yyyy',
                        ).format(
                          DateTime.now(),
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),

                      const SizedBox(height: 20),

                      // =========================
                      // SITE DROPDOWN
                      // =========================

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.shade400, width: 1),
                          borderRadius: BorderRadius.circular(
                            8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSite,
                            hint: const Text(
                              'Select Site',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                            isExpanded: true,
                            isDense: true,
                            iconSize: 20,
                            items: _siteNames.map(
                              (site) {
                                return DropdownMenuItem<String>(
                                  value: site,
                                  child: Text(
                                    site,
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSite = value;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      _buildAttendanceCard(
                        title: 'Office Time-In',
                        icon: Icons.login,
                        time: _officeTimeIn,
                        actionType: 'officeIn',
                      ),

                      _buildAttendanceCard(
                        title: 'Office Time-Out',
                        icon: Icons.logout,
                        time: _officeTimeOut,
                        actionType: 'officeOut',
                      ),
                    ],
                  ),
                ),
              ));
  }

  // =========================
  // CARD
  // =========================

  Widget _buildAttendanceCard({
    required String title,
    required IconData icon,
    required DateTime? time,
    required String actionType,
  }) {
    final status = _getStatusForCard(
      actionType,
    );

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.shade50,
              child: Icon(
                icon,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              status,
                            ).withOpacity(
                              0.2,
                            ),
                            borderRadius: BorderRadius.circular(
                              12,
                            ),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: _getStatusColor(
                                status,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time != null
                        ? DateFormat(
                            'hh:mm a',
                          ).format(
                            time,
                          )
                        : 'Not marked yet',
                    style: TextStyle(
                      color: time != null ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _shouldEnableButton(
                actionType,
              )
                  ? () async {
                      if (actionType == 'officeOut') {
                        await _confirmOfficeOut();
                      } else {
                        await _handleAction(
                          actionType,
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Mark',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // CONFIRM OFFICE OUT
  // =========================

  Future<void> _confirmOfficeOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirm',
        ),
        content: const Text(
          'Complete attendance for today?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                false,
              );
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                true,
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _handleAction(
        'officeOut',
      );
    }
  }
}
