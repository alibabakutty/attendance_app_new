import 'dart:convert';
import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:attendance_app/modals/geopoint.dart';
import 'package:geolocator/geolocator.dart';

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

  // ==========================================
  // GEOLOCATION RESOLVER & PERMISSION CHECKER
  // ==========================================
  Future<GeoPoint?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Test if location services are enabled globally on device.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('Location services are disabled. Please enable GPS.');
      return null;
    }

    // 2. Evaluate current runtime permissions.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Location permissions are denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar(
          'Location permissions are permanently denied. Update app settings.');
      return null;
    }

    // 3. Request high accuracy coordinate capture
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return GeoPoint(
          latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      debugPrint("Error fetching precise coordinates: $e");
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
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
        // Safe check for empty response body strings or generic error fragments
        if (response.body.trim().isEmpty) return;

        final Map<String, dynamic> data = jsonDecode(response.body);

        // Pad the standalone backend LocalTime with today's date string
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

        setState(() {
          _officeTimeIn = data['officeTimeIn'] != null
              ? DateTime.parse('$todayStr ${data['officeTimeIn']}')
              : null;

          _officeTimeOut = data['officeTimeOut'] != null
              ? DateTime.parse('$todayStr ${data['officeTimeOut']}')
              : null;

          _selectedSite = data['siteName'];
          _isSubmitted = _officeTimeOut != null;
        });
      } else if (response.statusCode == 404) {
        // If your endpoint yields a 404 when no entry exists for today yet
        setState(() {
          _officeTimeIn = null;
          _officeTimeOut = null;
          _selectedSite = null;
          _isSubmitted = false;
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

    // Set specific loading state
    setState(() {
      if (actionType == 'officeIn') {
        _isSavingIn = true;
      } else {
        _isSavingOut = true;
      }
    });

    try {
      // Fetch current GPS snapshot
      GeoPoint? currentGpsLocation = await _determinePosition();
      if (currentGpsLocation == null) {
        // Stop execution if tracking failed or permissions were denied
        return;
      }

      final body = {
        "employeeId": authProvider.employeeId,
        "employeeName": authProvider.username,
        "mobileNumber": authProvider.mobileNumber,
        "siteName": _selectedSite,
        "status": actionType,
        "tallyAttendanceStatus": "PENDING",
        "officeTimeInLocation":
            actionType == 'officeIn' ? currentGpsLocation.toJson() : null,
        "officeTimeOutLocation":
            actionType == 'officeOut' ? currentGpsLocation.toJson() : null,
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

                    // SITE LOCATION HEADING
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 5), // adjust to 0 or 1 if needed
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Site Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // SITE DROPDOWN
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                          onChanged: _selectedSite != null
                              ? null // disable dropdown after saved/fetched
                              : (value) {
                                  setState(() {
                                    _selectedSite = value;
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildAttendanceCard(
                      title: 'Office In-Time',
                      icon: Icons.login,
                      time: _officeTimeIn,
                      actionType: 'officeIn',
                    ),
                    const SizedBox(height: 10),
                    _buildAttendanceCard(
                      title: 'Office Out-Time',
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
                        if (actionType == 'officeOut') {
                          await _confirmOfficeOut();
                        } else {
                          await _handleAction(actionType);
                        }
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
