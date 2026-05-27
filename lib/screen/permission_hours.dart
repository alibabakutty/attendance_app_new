import 'dart:convert';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:attendance_app/modals/geopoint.dart';
import 'package:geolocator/geolocator.dart';

class PermissionHours extends StatefulWidget {
  const PermissionHours({super.key});

  @override
  State<PermissionHours> createState() => _PermissionHoursState();
}

class _PermissionHoursState extends State<PermissionHours> {
  final String baseUrl =
      dotenv.get('API_BASE_URL', fallback: 'http://192.168.1.3:8080');
  DateTime? _officeTimeIn;
  DateTime? _officeTimeOut;
  DateTime? _permissionTimeIn;
  DateTime? _permissionTimeOut;

  bool _isLoading = true;
  bool _isSavingIn = false; // Separate loading for Time-In
  bool _isSavingOut = false; // Separate loading for Time-Out

  String? employeeImageData;

  @override
  void initState() {
    super.initState();
    _fetchTodayAttendance();
    _fetchSiteNames();
  }

  String _getOverallAttendanceStatus() {
    // No office in = Absent
    if (_officeTimeIn == null) {
      return 'Absent';
    }

    // Office in exists, but office out not marked yet
    if (_officeTimeOut == null) {
      return 'In Progress';
    }

    // Calculate worked duration
    final workedDuration = _officeTimeOut!.difference(_officeTimeIn!);

    // Less than 5 hours = Half-Day
    if (workedDuration.inMinutes < 300) {
      return 'Half-Day';
    }

    // 5 hours or more = Present
    return 'Present';
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

        // Grab current date to structure standard format requirements
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

        setState(() {
          _officeTimeIn = data['officeTimeIn'] != null
              ? DateTime.parse('$todayStr ${data['officeTimeIn']}')
              : null;

          _officeTimeOut = data['officeTimeOut'] != null
              ? DateTime.parse('$todayStr ${data['officeTimeOut']}')
              : null;

          _permissionTimeIn = data['permissionTimeIn'] != null
              ? DateTime.parse('$todayStr ${data['permissionTimeIn']}')
              : null;

          _permissionTimeOut = data['permissionTimeOut'] != null
              ? DateTime.parse('$todayStr ${data['permissionTimeOut']}')
              : null;
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
        jsonDecode(response.body);

        setState(() {});
      }
    } catch (e) {
      debugPrint('Site Fetch Error: $e');
    }
  }

  // =========================
  // GEOLOCATION SERVICE HELPER
  // =========================

  Future<GeoPoint?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if device location services are globally switched on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(
          'Location services are disabled. Please turn on GPS.', Colors.red);
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission requests were denied.', Colors.red);
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
        'Location permissions are permanently denied. Please update app system settings.',
        Colors.red,
      );
      return null;
    }

    // High accuracy ensures high-grade GPS logging coordinates are captured
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return GeoPoint(latitude: position.latitude, longitude: position.longitude);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // =========================
  // MARK ATTENDANCE
  // =========================

  Future<void> _setPermissionTime(String actionType) async {
    final authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null) return;

    final now = DateTime.now();

    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );

    // Initial check to avoid location overhead if timelines are inverted
    if (actionType == 'permissionOut' &&
        _permissionTimeIn != null &&
        selectedDateTime.isBefore(_permissionTimeIn!)) {
      _showSnackBar(
          'Permission end cannot be before permission start', Colors.red);
      return;
    }

    // Set loading indicator flags to change targeted button to spinner UI layout
    setState(() {
      if (actionType == 'permissionIn') _isSavingIn = true;
      if (actionType == 'permissionOut') _isSavingOut = true;
    });

    try {
      // Pull system coordinates
      GeoPoint? currentPosition = await _determinePosition();
      if (currentPosition == null) {
        // Stop execution if location setup or extraction fails
        return;
      }

      final body = {
        "employeeId": authProvider.employeeId ?? "1001",
        "employeeName": authProvider.username ?? "",
        "mobileNumber": authProvider.mobileNumber ?? "",
        "permissionTimeIn": actionType == 'permissionIn'
            ? selectedDateTime.toIso8601String()
            : null,
        "permissionTimeInLocation":
            actionType == 'permissionIn' ? currentPosition.toJson() : null,
        "permissionTimeOut": actionType == 'permissionOut'
            ? selectedDateTime.toIso8601String()
            : null,
        "permissionTimeOutLocation":
            actionType == 'permissionOut' ? currentPosition.toJson() : null,
        if (actionType == 'permissionIn') "tallyPermissionStatus": "PENDING",
      };

      final response = await http.put(
        Uri.parse(
          '$baseUrl/api/v1/attendance-masters/update-permission',
        ),
        headers: {
          ...authProvider.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          if (actionType == 'permissionIn') {
            _permissionTimeIn = selectedDateTime;
          } else if (actionType == 'permissionOut') {
            _permissionTimeOut = selectedDateTime;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission time updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        if (actionType == 'permissionIn') _isSavingIn = false;
        if (actionType == 'permissionOut') _isSavingOut = false;
      });
    }
  }

  // =========================
  // BUTTON ENABLE
  // =========================

  bool _shouldEnableButton(String actionType) {
    switch (actionType) {
      case 'permissionIn':
        return _permissionTimeIn == null;

      case 'permissionOut':
        return _permissionTimeIn != null && _permissionTimeOut == null;

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

  String _getPermissionHours() {
    if (_permissionTimeIn == null || _permissionTimeOut == null) {
      return 'Not completed';
    }

    final duration = _permissionTimeOut!.difference(_permissionTimeIn!);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '$hours Hours $minutes Minutes $seconds Seconds';
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
          'Permission Hours',
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
                    color: Colors.black.withValues(alpha: 0.08),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${authProvider.employeeId ?? ''} - ${authProvider.username ?? ''}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Employee Details',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              _getOverallAttendanceStatus(),
                            ).withValues(alpha: 0.15),
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
                            color: Colors.black.withValues(alpha: 0.08),
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

                    _buildAttendanceCard(
                      title: 'Permission Start',
                      icon: Icons.login,
                      time: _permissionTimeIn,
                      actionType: 'permissionIn',
                    ),

                    _buildAttendanceCard(
                      title: 'Permission End',
                      icon: Icons.logout,
                      time: _permissionTimeOut,
                      actionType: 'permissionOut',
                    ),

                    const SizedBox(height: 10),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(
                                Icons.schedule,
                                color: Colors.blue.shade800,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Permission Hours',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _getPermissionHours(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
    bool isLoading = actionType == 'permissionIn' ? _isSavingIn : _isSavingOut;
    bool showButton = _shouldEnableButton(actionType);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade50,
              child: Icon(
                icon,
                color: Colors.blue.shade800,
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            /// Title
            Flexible(
              flex: 3,
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: time != null ? Colors.black : Colors.grey,
                ),
              ),
            ),

            /// Mark Button
            if (showButton) ...[
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await _setPermissionTime(actionType);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  minimumSize: const Size(60, 34),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
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
}
