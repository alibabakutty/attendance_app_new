import 'dart:convert';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MarkAttendance extends StatefulWidget {
  const MarkAttendance({super.key});

  @override
  State<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> {
  final String baseUrl =
      dotenv.get('API_BASE_URL', fallback: 'http://192.168.1.3:8080');
  DateTime? _officeTimeIn;
  DateTime? _officeTimeOut;

  bool _isSubmitted = false;
  bool _isLoading = true;
  bool _isSavingIn = false; // Separate loading for Time-In
  bool _isSavingOut = false; // Separate loading for Time-Out

  List<String> _siteNames = [];
  String? _selectedSite;
  String? employeeImageData;

  @override
  void initState() {
    super.initState();
    _fetchTodayAttendance();
    _fetchSiteNames();
  }

  String _getOverallAttendanceStatus() {
    // Initial state
    if (_officeTimeIn == null && _officeTimeOut == null) {
      return 'Absent';
    }

    // After Office Time-In only
    if (_officeTimeIn != null && _officeTimeOut == null) {
      return 'Half-Day';
    }

    // After Office Time-Out
    if (_officeTimeIn != null && _officeTimeOut != null) {
      return 'Present';
    }

    return 'Absent';
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
          '$baseUrl/api/v1/attendance-masters/today/${authProvider.username}',
        ),
        headers: authProvider.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _officeTimeIn = data['officeTimeIn'] != null
              ? DateTime.parse(data['officeTimeIn'])
              : null;

          _officeTimeOut = data['officeTimeOut'] != null
              ? DateTime.parse(data['officeTimeOut'])
              : null;

          _selectedSite = data['siteName'];
          _isSubmitted = _officeTimeOut != null;
        });
      }
    } catch (e) {
      debugPrint('Fetch Attendance Error: $e');
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
          '$baseUrl/api/v1/site-name-masters',
        ),
        headers: authProvider.authHeaders,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          _siteNames =
              data.map<String>((e) => e['siteName'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Site Fetch Error: $e');
    }
  }

  // =========================
  // TIME VALIDATION
  // =========================

  bool _isWithinOfficeTimeInRange(DateTime time) {
    final authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    final start = DateTime(time.year, time.month, time.day, 9, 0);
    final end = authProvider.isAdmin
        ? DateTime(time.year, time.month, time.day, 10, 30)
        : DateTime(time.year, time.month, time.day, 9, 45);

    return time.isAfter(start.subtract(const Duration(seconds: 1))) &&
        time.isBefore(end.add(const Duration(seconds: 1)));
  }

  bool _isWithinOfficeTimeOutRange(DateTime time) {
    final start = DateTime(time.year, time.month, time.day, 18, 30);
    final end = DateTime(time.year, time.month, time.day, 19, 15);

    return time.isAfter(start.subtract(const Duration(seconds: 1))) &&
        time.isBefore(end.add(const Duration(seconds: 1)));
  }

  // =========================
  // MARK ATTENDANCE
  // =========================

  Future<void> _handleAction(String actionType) async {
    // Check specific loading state
    if (actionType == 'officeIn' && _isSavingIn) return;
    if (actionType == 'officeOut' && _isSavingOut) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final now = DateTime.now();

    // Validation Logic
    if (actionType == 'officeIn' && _selectedSite == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select site')));
      return;
    }

    try {
      // Set specific loading state
      setState(() {
        if (actionType == 'officeIn') {
          _isSavingIn = true;
        } else {
          _isSavingOut = true;
        }
      });

      final body = {
        "employeeId": authProvider.employeeId ?? "1001",
        "employeeName": authProvider.username ?? "Perumal",
        "mobileNumber": authProvider.mobileNumber ?? "9940013931",
        "siteName": _selectedSite,
        "status": actionType,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/attendance-masters/mark'),
        headers: {
          ...authProvider.authHeaders,
          'Content-Type': 'application/json',
        },
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
            content: Text('$actionType marked successfully'),
          ),
        );
      } else {
        print("Server Error: ${response.body}");
        throw Exception('Status Code: ${response.statusCode}');
      }
    } catch (e) {
      print("Connection Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: $e'),
        ),
      );
    } finally {
      // Clear specific loading state
      setState(() {
        if (actionType == 'officeIn') {
          _isSavingIn = false;
        } else {
          _isSavingOut = false;
        }
      });
    }
  }

  // =========================
  // BUTTON ENABLE
  // =========================

  bool _shouldEnableButton(String actionType) {
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

  Color _getStatusColor(String status) {
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

  void _onLogout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Logout'),
            onPressed: () {
              Navigator.of(context).pop();
              authProvider.logout();
              Navigator.of(context).pushReplacementNamed('/employeeLogin');
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFdcf2fb),
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        title: const Text(
          'Mark Attendance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _onLogout(context);
            },
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE3F2FD), // Light Blue
                    Color(0xFFBBDEFB), // Soft Blue
                    Color(0xFF90CAF9), // Medium Light Blue
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: Colors.blueGrey.shade300,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // HEADER: EMPTY | USERNAME | STATUS
                    Row(
                      children: [
                        // LEFT EMPTY SPACE
                        const SizedBox(width: 90),
                        // CENTER USERNAME
                        Expanded(
                          child: Center(
                            child: Text(
                              authProvider.username ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // RIGHT STATUS CARD
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              _getOverallAttendanceStatus(),
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getOverallAttendanceStatus(),
                            style: TextStyle(
                              color: _getStatusColor(
                                _getOverallAttendanceStatus(),
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // PORTRAIT EMPLOYEE IMAGE
                    Container(
                      width: MediaQuery.of(context).size.width * 0.55,
                      height: MediaQuery.of(context).size.height * 0.32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: authProvider.employeeImageData != null &&
                                authProvider.employeeImageData!.isNotEmpty
                            ? Image.memory(
                                base64Decode(authProvider.employeeImageData!),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade100,
                                child: const Icon(
                                  Icons.person,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DATE
                    Text(
                      DateFormat('EEEE, MMM d yyyy').format(DateTime.now()),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // SITE DROPDOWN
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSite,
                          hint: const Text(
                            'Select Site',
                            style: TextStyle(fontSize: 14),
                          ),
                          isExpanded: true,
                          isDense: true,
                          iconSize: 20,
                          items: _siteNames.map((site) {
                            return DropdownMenuItem<String>(
                              value: site,
                              child: Text(
                                site,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
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
                    const SizedBox(height: 10),
                    _buildAttendanceCard(
                      title: 'Office Time-Out',
                      icon: Icons.logout,
                      time: _officeTimeOut,
                      actionType: 'officeOut',
                    ),
                  ],
                ),
              ),
            ),
    );
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
    bool isLoading = actionType == 'officeIn' ? _isSavingIn : _isSavingOut;
    bool showButton = _shouldEnableButton(actionType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.shade50,
              child: Icon(
                icon,
                color: Colors.blue.shade800,
                size: 26,
              ),
            ),

            const SizedBox(width: 12),

            /// Title
            Flexible(
              flex: 3,
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(width: 8),

            /// Time
            Expanded(
              flex: showButton ? 2 : 3,
              child: Text(
                time != null
                    ? DateFormat('hh:mm a').format(time)
                    : 'Not marked yet',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: time != null ? Colors.black : Colors.grey,
                ),
              ),
            ),

            /// Mark Button
            if (showButton) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (actionType == 'officeOut') {
                          await _confirmOfficeOut();
                        } else {
                          await _handleAction(actionType);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  minimumSize: const Size(70, 40),
                ),
                child: isLoading
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
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
        title: const Text('Confirm'),
        content: const Text('Complete attendance for today?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _handleAction('officeOut');
    }
  }
}
