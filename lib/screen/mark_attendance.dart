import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class MarkAttendance extends StatefulWidget {
  const MarkAttendance({super.key});

  @override
  State<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> {
  final Map<String, Position?> _locationMap = {
    'officeIn': null,
    'lunchStart': null,
    'lunchEnd': null,
    'officeOut': null,
  };

  DateTime? _officeTimeIn;
  DateTime? _lunchTimeStart;
  DateTime? _lunchTimeEnd;
  DateTime? _officeTimeOut;
  bool _isSubmitted = false;
  String _locationError = '';
  bool _isLoading = true;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _fetchTodayAttendance();
  }

  // Helper methods for time validation
  bool _isWithinOfficeTimeInRange(DateTime time) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final now = time;
    if (authProvider.isExceptTimeIn) {
      // For exceptional users: 9:00 AM to 10:30 AM
      final startTime = DateTime(now.year, now.month, now.day, 9, 00);
      final endTime = DateTime(now.year, now.month, now.day, 10, 30);
      return now.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
          now.isBefore(endTime.add(const Duration(seconds: 1)));
    } else {
      // For normal users: 9:00 AM to 9:45 AM
      final startTime = DateTime(now.year, now.month, now.day, 9, 00);
      final endTime = DateTime(now.year, now.month, now.day, 9, 45);
      return now.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
          now.isBefore(endTime.add(const Duration(seconds: 1)));
    }
  }

  bool _isWithinLunchTimeRange(DateTime time) {
    final now = time;
    final startTime = DateTime(now.year, now.month, now.day, 13, 15);
    final endTime = DateTime(now.year, now.month, now.day, 14, 30);
    return now.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
        now.isBefore(endTime.add(const Duration(seconds: 1)));
  }

  bool _isWithinOfficeTimeOutRange(DateTime time) {
    final now = time;
    final startTime = DateTime(now.year, now.month, now.day, 18, 30);
    final endTime = DateTime(now.year, now.month, now.day, 19, 15);
    return now.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
        now.isBefore(endTime.add(const Duration(seconds: 1)));
  }

  String _getTimeWarning(DateTime time, String actionType) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    switch (actionType) {
      case 'officeIn':
        if (_isWithinOfficeTimeInRange(time)) return '';
        final startTime = DateTime(time.year, time.month, time.day, 9, 00);

        // Custom message for exceptional users
        if (authProvider.isExceptTimeIn) {
          return time.isBefore(startTime)
              ? '⚠️ Too early (allowed after 9:00 AM)'
              : '⚠️ Too late (allowed before 10:30 AM)';
        }

        // Normal message
        return time.isBefore(startTime)
            ? '⚠️ Too early (allowed after 9:00 AM)'
            : '⚠️ Too late (allowed before 9:45 AM)';

      case 'lunchStart':
      case 'lunchEnd':
        if (_isWithinLunchTimeRange(time)) return '';
        final startTime = DateTime(time.year, time.month, time.day, 13, 15);
        return time.isBefore(startTime)
            ? '⚠️ Too early (allowed after 1:15 PM)'
            : '⚠️ Too late (allowed before 2:30 PM)';

      case 'officeOut':
        if (_isWithinOfficeTimeOutRange(time)) return '';
        final startTime = DateTime(time.year, time.month, time.day, 18, 30);
        return time.isBefore(startTime)
            ? '⚠️ Too early (allowed after 6:30 PM)'
            : '⚠️ Too late (allowed before 7:15 PM)';

      default:
        return '';
    }
  }

  Future<void> _fetchTodayAttendance() async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final today = DateTime.now();
      final docId =
          '${authProvider.employeeId}_${DateFormat('yyyyMMdd').format(today)}';

      final doc = await FirebaseFirestore.instance
          .collection('mark_attendance_data')
          .doc(docId)
          .get();

      if (doc.exists && mounted) {
        final attendanceData = MarkAttendanceData.fromFirestore(doc.data()!);
        setState(() {
          _officeTimeIn = attendanceData.officeTimeIn?.toDate();
          _lunchTimeStart = attendanceData.lunchTimeStart?.toDate();
          _lunchTimeEnd = attendanceData.lunchTimeEnd?.toDate();
          _officeTimeOut = attendanceData.officeTimeOut?.toDate();
          _isSubmitted = _officeTimeOut != null;

          _updateLocationFromData(
            'officeIn',
            attendanceData.officeTimeInLocation,
          );
          _updateLocationFromData(
            'lunchStart',
            attendanceData.lunchTimeStartLocation,
          );
          _updateLocationFromData(
            'lunchEnd',
            attendanceData.lunchTimeEndLocation,
          );
          _updateLocationFromData(
            'officeOut',
            attendanceData.officeTimeOutLocation,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching attendance: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetching = false;
        });
      }
    }
  }

  void _updateLocationFromData(String key, GeoPoint? location) {
    if (location != null && location.latitude != 0) {
      _locationMap[key] = Position(
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        setState(() {
          _locationError = 'Location services are disabled.';
        });
        return null;
      }

      PermissionStatus status = await Permission.location.status;
      if (status.isDenied ||
          status.isRestricted ||
          status.isPermanentlyDenied) {
        final newStatus = await Permission.location.request();
        if (newStatus.isPermanentlyDenied) {
          setState(() {
            _locationError =
                'Location permission permanently denied. Please enable it from settings.';
          });
          openAppSettings();
          return null;
        }
        if (!newStatus.isGranted) {
          setState(() {
            _locationError = 'Location permission denied.';
          });
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _locationError = '';
      });

      return position;
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
      });
      return null;
    }
  }

  String _formatLocation(Position? pos) {
    return pos != null
        ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}'
        : 'Location not available';
  }

  Future<void> _handleAction(String actionType) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final position = await _getCurrentLocation();
    if (position == null) return;

    final now = DateTime.now();

    // Special case: Office time-in after normal hours
    if (actionType == 'officeIn') {
      // For exceptional users - block after 10:30 AM
      if (authProvider.isExceptTimeIn &&
          (now.hour > 10 || (now.hour == 10 && now.minute > 30))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Office Time-in not allowed after 10:30 AM"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      // For normal users - block after 9:45 AM
      else if (!authProvider.isExceptTimeIn &&
          (now.hour > 9 || (now.hour == 9 && now.minute > 45))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Office Time-in not allowed after 9:45 AM"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Check for time restrictions
    bool isWithinTimeRange = true;
    switch (actionType) {
      case 'officeIn':
        isWithinTimeRange = _isWithinOfficeTimeInRange(now);
        break;
      case 'lunchStart':
      case 'lunchEnd':
        isWithinTimeRange = _isWithinLunchTimeRange(now);
        break;
      case 'officeOut':
        isWithinTimeRange = _isWithinOfficeTimeOutRange(now);
        break;
    }

    if (!isWithinTimeRange) {
      final warning = _getTimeWarning(now, actionType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
      // Still allow marking but with warning
    }

    setState(() {
      _locationMap[actionType] = position;

      switch (actionType) {
        case 'officeIn':
          _officeTimeIn = now;
          break;
        case 'lunchStart':
          _lunchTimeStart = now;
          break;
        case 'lunchEnd':
          _lunchTimeEnd = now;
          break;
        case 'officeOut':
          _officeTimeOut = now;
          _isSubmitted = true;
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$actionType recorded at ${DateFormat('hh:mm a').format(now)}',
            ),
            Text(
              _formatLocation(position),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    await _saveAttendanceToFirestore();
  }

  Future<void> _saveAttendanceToFirestore() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final now = DateTime.now();
      final docId =
          '${authProvider.employeeId}_${DateFormat('yyyyMMdd').format(now)}';

      // Determine status based on actions
      String status = 'absent';
      if (_officeTimeIn != null) {
        if (_officeTimeOut != null) {
          // check if lunch time was taken (both start and end)
          if (_lunchTimeStart != null && _lunchTimeEnd != null) {
            status = 'present';
          } else {
            // office time in and out marked but not lunch taken (or incomplete lunch)
            status = 'half-day';
          }
        } else {
          // only office time in marked
          status = 'half-day';
        }
      }

      final markAttendanceData = MarkAttendanceData(
        employeeId: authProvider.employeeId!,
        employeeName: authProvider.username!,
        mobileNumber: authProvider.mobileNumber!,
        attendanceDate: Timestamp.fromDate(now),
        officeTimeIn:
            _officeTimeIn != null ? Timestamp.fromDate(_officeTimeIn!) : null,
        officeTimeInLocation: _locationMap['officeIn'] != null
            ? GeoPoint(
                _locationMap['officeIn']!.latitude,
                _locationMap['officeIn']!.longitude,
              )
            : null,
        lunchTimeStart: _lunchTimeStart != null
            ? Timestamp.fromDate(_lunchTimeStart!)
            : null,
        lunchTimeStartLocation: _locationMap['lunchStart'] != null
            ? GeoPoint(
                _locationMap['lunchStart']!.latitude,
                _locationMap['lunchStart']!.longitude,
              )
            : null,
        lunchTimeEnd:
            _lunchTimeEnd != null ? Timestamp.fromDate(_lunchTimeEnd!) : null,
        lunchTimeEndLocation: _locationMap['lunchEnd'] != null
            ? GeoPoint(
                _locationMap['lunchEnd']!.latitude,
                _locationMap['lunchEnd']!.longitude,
              )
            : null,
        officeTimeOut:
            _officeTimeOut != null ? Timestamp.fromDate(_officeTimeOut!) : null,
        officeTimeOutLocation: _locationMap['officeOut'] != null
            ? GeoPoint(
                _locationMap['officeOut']!.latitude,
                _locationMap['officeOut']!.longitude,
              )
            : null,
        status: status,
      );

      await FirebaseFirestore.instance
          .collection('mark_attendance_data')
          .doc(docId)
          .set(markAttendanceData.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: ${e.toString()}')),
        );
      }
    }
  }

  bool _shouldEnableButton(String actionType) {
    switch (actionType) {
      case 'officeIn':
        return _officeTimeIn == null;
      case 'lunchStart':
        return _officeTimeIn != null &&
            _lunchTimeStart == null &&
            _officeTimeOut == null;
      case 'lunchEnd':
        return _lunchTimeStart != null &&
            _lunchTimeEnd == null &&
            _officeTimeOut == null;
      case 'officeOut':
        return _officeTimeIn != null && _officeTimeOut == null;
      default:
        return false;
    }
  }

  String _getStatusForCard(String actionType) {
    if (_officeTimeOut != null) return 'Completed';
    if (_officeTimeIn == null) return actionType == 'officeIn' ? 'Absent' : '';
    if (actionType == 'officeIn' && _officeTimeIn != null) return 'Present';
    if (actionType == 'lunchStart' && _lunchTimeStart != null) return 'Present';
    if (actionType == 'lunchEnd' && _lunchTimeEnd != null) return 'Present';
    if (actionType == 'officeOut' && _officeTimeOut != null) return 'Completed';
    return '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Today: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (_locationError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _locationError,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _buildAttendanceCard(
                    icon: Icons.login,
                    title: 'Office Time-In',
                    time: _officeTimeIn,
                    location: _locationMap['officeIn'],
                    actionType: 'officeIn',
                  ),
                  _buildAttendanceCard(
                    icon: Icons.restaurant,
                    title: 'Lunch Start',
                    time: _lunchTimeStart,
                    location: _locationMap['lunchStart'],
                    actionType: 'lunchStart',
                  ),
                  _buildAttendanceCard(
                    icon: Icons.restaurant_menu,
                    title: 'Lunch End',
                    time: _lunchTimeEnd,
                    location: _locationMap['lunchEnd'],
                    actionType: 'lunchEnd',
                  ),
                  _buildAttendanceCard(
                    icon: Icons.logout,
                    title: 'Office Time-Out',
                    time: _officeTimeOut,
                    location: _locationMap['officeOut'],
                    actionType: 'officeOut',
                  ),
                  if (_isSubmitted)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Attendance Completed',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildAttendanceCard({
    required IconData icon,
    required String title,
    required DateTime? time,
    required Position? location,
    required String actionType,
  }) {
    final status = _getStatusForCard(actionType);
    bool showWarning = false;
    String warningMessage = '';

    if (time != null) {
      switch (actionType) {
        case 'officeIn':
          showWarning = !_isWithinOfficeTimeInRange(time);
          break;
        case 'lunchStart':
        case 'lunchEnd':
          showWarning = !_isWithinLunchTimeRange(time);
          break;
        case 'officeOut':
          showWarning = !_isWithinOfficeTimeOutRange(time);
          break;
      }
      if (showWarning) {
        warningMessage = _getTimeWarning(time, actionType);
      }
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.blue[800], size: 24),
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
                          if (status.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time != null
                            ? DateFormat('hh:mm a').format(time)
                            : 'Not marked yet',
                        style: TextStyle(
                          color: time != null
                              ? (showWarning ? Colors.orange : Colors.green)
                              : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      if (showWarning)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                warningMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (location != null && !showWarning)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatLocation(location),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _shouldEnableButton(actionType)
                      ? () => actionType == 'officeOut'
                          ? _confirmOfficeOut()
                          : _handleAction(actionType)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _shouldEnableButton(actionType)
                        ? Colors.blue[800]
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Mark',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOfficeOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Office Time-Out'),
        content: const Text(
          'This will complete your attendance for today. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleAction('officeOut');
    }
  }
}
