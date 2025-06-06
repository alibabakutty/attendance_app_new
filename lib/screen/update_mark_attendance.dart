import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:attendance_app/service/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateMarkAttendance extends StatefulWidget {
  const UpdateMarkAttendance({
    super.key,
    this.mobileNumberArgs,
    this.existingAttendance,
    this.employeeName,
    this.employeeId,
  });

  final String? mobileNumberArgs;
  final MarkAttendanceData? existingAttendance;
  final String? employeeName;
  final String? employeeId;

  @override
  State<UpdateMarkAttendance> createState() => _UpdateMarkAttendanceState();
}

class _UpdateMarkAttendanceState extends State<UpdateMarkAttendance> {
  final FirebaseService _firebaseService = FirebaseService();
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
  bool _isEditing = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate =
        widget.existingAttendance?.attendanceDate?.toDate() ?? DateTime.now();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _fetchAttendanceForSelectedDate();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Initialization error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAttendanceForSelectedDate() async {
    if (_isFetching || widget.mobileNumberArgs == null) return;
    setState(() => _isFetching = true);

    try {
      // First check if we have existing attendance data passed in
      if (widget.existingAttendance != null &&
          DateFormat(
                'yyyy-MM-dd',
              ).format(widget.existingAttendance!.attendanceDate!.toDate()) ==
              DateFormat('yyyy-MM-dd').format(_selectedDate)) {
        _populateDataFromExisting(widget.existingAttendance!);
        return;
      }

      // Otherwise fetch from Firebase
      final attendanceData = await _firebaseService
          .fetchAttendanceByMobileNumberWithSpecificDate(
            widget.mobileNumberArgs!,
            _selectedDate,
          );

      if (attendanceData != null && mounted) {
        _populateDataFromExisting(attendanceData);
      } else {
        // No existing data for selected date - reset fields
        setState(() {
          _officeTimeIn = null;
          _lunchTimeStart = null;
          _lunchTimeEnd = null;
          _officeTimeOut = null;
          _isSubmitted = false;
          _isEditing = false;
          _locationMap.forEach((key, value) => _locationMap[key] = null);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Fetch error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchAttendanceForSelectedDate();
    }
  }

  void _populateDataFromExisting(MarkAttendanceData attendanceData) {
    setState(() {
      _officeTimeIn = attendanceData.officeTimeIn?.toDate();
      _lunchTimeStart = attendanceData.lunchTimeStart?.toDate();
      _lunchTimeEnd = attendanceData.lunchTimeEnd?.toDate();
      _officeTimeOut = attendanceData.officeTimeOut?.toDate();
      _isSubmitted = _officeTimeOut != null;
      _isEditing = true;

      _updateLocationFromData('officeIn', attendanceData.officeTimeInLocation);
      _updateLocationFromData(
        'lunchStart',
        attendanceData.lunchTimeStartLocation,
      );
      _updateLocationFromData('lunchEnd', attendanceData.lunchTimeEndLocation);
      _updateLocationFromData(
        'officeOut',
        attendanceData.officeTimeOutLocation,
      );
    });
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

  Future<void> _showTimeUpdateDialog(String actionType) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null && mounted) {
      final updatedTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        time.hour,
        time.minute,
      );

      setState(() {
        switch (actionType) {
          case 'officeIn':
            _officeTimeIn = updatedTime;
            break;
          case 'lunchStart':
            _lunchTimeStart = updatedTime;
            break;
          case 'lunchEnd':
            _lunchTimeEnd = updatedTime;
            break;
          case 'officeOut':
            _officeTimeOut = updatedTime;
            _isSubmitted = true;
            break;
        }
      });

      await _saveAttendanceToFirestore();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        setState(() => _locationError = 'Location services are disabled.');
        return null;
      }

      PermissionStatus status = await Permission.location.status;
      if (status.isDenied || status.isPermanentlyDenied) {
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
          setState(() => _locationError = 'Location permission denied.');
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _locationError = '');
      return position;
    } catch (e) {
      setState(() => _locationError = 'Error getting location: $e');
      return null;
    }
  }

  Future<void> _handleAction(String actionType) async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    final now = DateTime.now();
    final updatedTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
    );

    final warning = _getTimeWarning(updatedTime, actionType);
    if (warning.isNotEmpty) {
      _showWarningSnackBar(warning);
    }

    setState(() {
      _locationMap[actionType] = position;
      switch (actionType) {
        case 'officeIn':
          _officeTimeIn = updatedTime;
          break;
        case 'lunchStart':
          _lunchTimeStart = updatedTime;
          break;
        case 'lunchEnd':
          _lunchTimeEnd = updatedTime;
          break;
        case 'officeOut':
          _officeTimeOut = updatedTime;
          _isSubmitted = true;
          break;
      }
    });

    await _saveAttendanceToFirestore();
  }

  Future<void> _saveAttendanceToFirestore() async {
    try {
      if (_selectedDate.isAfter(DateTime.now())) {
        if (mounted) {
          _showErrorSnackBar('Cannot save attendance for future dates');
        }
        return;
      }

      final status = _calculateStatus();

      final attendanceData = MarkAttendanceData(
        employeeId: widget.employeeId ?? '',
        employeeName: widget.employeeName ?? '',
        mobileNumber: widget.mobileNumberArgs ?? '',
        attendanceDate: Timestamp.fromDate(_selectedDate),
        officeTimeIn: _officeTimeIn != null
            ? Timestamp.fromDate(_officeTimeIn!)
            : null,
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
        lunchTimeEnd: _lunchTimeEnd != null
            ? Timestamp.fromDate(_lunchTimeEnd!)
            : null,
        lunchTimeEndLocation: _locationMap['lunchEnd'] != null
            ? GeoPoint(
                _locationMap['lunchEnd']!.latitude,
                _locationMap['lunchEnd']!.longitude,
              )
            : null,
        officeTimeOut: _officeTimeOut != null
            ? Timestamp.fromDate(_officeTimeOut!)
            : null,
        officeTimeOutLocation: _locationMap['officeOut'] != null
            ? GeoPoint(
                _locationMap['officeOut']!.latitude,
                _locationMap['officeOut']!.longitude,
              )
            : null,
        status: status,
      );

      if (_isEditing) {
        // Update existing record
        await _firebaseService.updateMarkAttendanceDataByMobileNumber(
          widget.mobileNumberArgs!,
          attendanceData.toFirestore(),
        );
      } else {
        // Create new record
        await _firebaseService.addNewMarkAttendanceData(attendanceData);
        setState(() => _isEditing = true);
      }

      if (mounted) {
        _showSuccessSnackBar('Attendance saved successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Save error: ${e.toString()}');
      }
    }
  }

  String _calculateStatus() {
    if (_officeTimeIn == null) return 'absent';
    if (_officeTimeOut == null) return 'half-day';
    return (_lunchTimeStart != null && _lunchTimeEnd != null)
        ? 'present'
        : 'half-day';
  }

  bool _isWithinOfficeTimeInRange(DateTime time) {
    final startTime = DateTime(time.year, time.month, time.day, 9, 30);
    final endTime = DateTime(time.year, time.month, time.day, 10, 15);
    return time.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
        time.isBefore(endTime.add(const Duration(seconds: 1)));
  }

  bool _isWithinLunchTimeRange(DateTime time) {
    final startTime = DateTime(time.year, time.month, time.day, 13, 15);
    final endTime = DateTime(time.year, time.month, time.day, 14, 30);
    return time.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
        time.isBefore(endTime.add(const Duration(seconds: 1)));
  }

  bool _isWithinOfficeTimeOutRange(DateTime time) {
    final startTime = DateTime(time.year, time.month, time.day, 18, 30);
    final endTime = DateTime(time.year, time.month, time.day, 19, 15);
    return time.isAfter(startTime.subtract(const Duration(seconds: 1))) &&
        time.isBefore(endTime.add(const Duration(seconds: 1)));
  }

  String _getTimeWarning(DateTime time, String actionType) {
    switch (actionType) {
      case 'officeIn':
        if (_isWithinOfficeTimeInRange(time)) return '';
        final startTime = DateTime(time.year, time.month, time.day, 9, 30);
        return time.isBefore(startTime)
            ? '⚠️ Too early (allowed after 9:30 AM)'
            : '⚠️ Too late (allowed before 10:15 AM)';
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Update Attendance for ${widget.employeeName ?? widget.mobileNumberArgs}',
          style: const TextStyle(color: Colors.white),
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
                  InkWell(
                    onTap: _isFetching ? null : () => _selectDate(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Selected Date: ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                        ),
                        if (_isFetching)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
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
                  const Divider(),
                  const Text(
                    'Admin Controls',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _showTimeUpdateDialog('officeIn'),
                        child: const Text('Update Office In'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showTimeUpdateDialog('lunchStart'),
                        child: const Text('Update Lunch Start'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showTimeUpdateDialog('lunchEnd'),
                        child: const Text('Update Lunch End'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showTimeUpdateDialog('officeOut'),
                        child: const Text('Update Office Out'),
                      ),
                    ],
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
                            'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.mobileNumberArgs != null)
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

  bool _shouldEnableButton(String actionType) {
    if (_isSubmitted) return false;
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
}
