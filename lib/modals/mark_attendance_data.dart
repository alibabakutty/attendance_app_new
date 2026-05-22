import 'package:attendance_app/modals/geopoint.dart';

class MarkAttendanceData {
  final String employeeId;
  final String employeeName;
  final String? mobileNumber;
  final DateTime? attendanceDate;
  final String? siteName;
  final DateTime? officeTimeIn;
  final GeoPoint? officeTimeInLocation;
  final DateTime? officeTimeOut;
  final GeoPoint? officeTimeOutLocation;
  final DateTime? permissionTimeIn;
  final GeoPoint? permissionTimeInLocation;
  final DateTime? permissionTimeOut;
  final GeoPoint? permissionTimeOutLocation;
  final String status;
  final String? tallyAttendanceStatus;
  final String? tallyPermissionStatus;

  MarkAttendanceData({
    required this.employeeId,
    required this.employeeName,
    this.mobileNumber,
    this.attendanceDate,
    this.siteName,
    this.officeTimeIn,
    this.officeTimeInLocation,
    this.officeTimeOut,
    this.officeTimeOutLocation,
    this.permissionTimeIn,
    this.permissionTimeInLocation,
    this.permissionTimeOut,
    this.permissionTimeOutLocation,
    required this.status,
    this.tallyAttendanceStatus,
    this.tallyPermissionStatus
  });

  factory MarkAttendanceData.fromJson(Map<String, dynamic> json) {
    return MarkAttendanceData(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      mobileNumber: json['mobileNumber'],
      attendanceDate: json['attendanceDate'] != null
          ? DateTime.parse(json['attendanceDate'])
          : null,
      siteName: json['siteName'],
      officeTimeIn: json['officeTimeIn'] != null
          ? DateTime.parse(json['officeTimeIn'])
          : null,
      officeTimeInLocation: json['officeTimeInLocation'] != null
          ? GeoPoint.fromJson(json['officeTimeInLocation'])
          : null,
      officeTimeOut: json['officeTimeOut'] != null
          ? DateTime.parse(json['officeTimeOut'])
          : null,
      officeTimeOutLocation: json['officeTimeOutLocation'] != null
          ? GeoPoint.fromJson(json['officeTimeOutLocation'])
          : null,
      permissionTimeIn: json['permissionTimeIn'] != null
          ? DateTime.parse(json['permissionTimeIn'])
          : null,
      permissionTimeInLocation: json['permissionTimeInLocation'] != null
          ? GeoPoint.fromJson(json['permissionTimeInLocation'])
          : null,
      permissionTimeOut: json['permissionTimeOut'] != null
          ? DateTime.parse(json['permissionTimeOut'])
          : null,
      permissionTimeOutLocation: json['permissionTimeOutLocation'] != null
          ? GeoPoint.fromJson(json['permissionTimeOutLocation'])
          : null,
      status: json['status'] ?? 'ABSENT',
      tallyAttendanceStatus: json['tallyAttendanceStatus'] ?? null,
      tallyPermissionStatus: json['tallyPermissionStatus'] ?? null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "employeeId": employeeId,
      "employeeName": employeeName,
      "mobileNumber": mobileNumber,
      "attendanceDate": attendanceDate?.toIso8601String().split('T')[0],
      "siteName": siteName,
      "officeTimeIn": officeTimeIn?.toIso8601String(),
      "officeTimeInLocation": officeTimeInLocation?.toJson(),
      "officeTimeOut": officeTimeOut?.toIso8601String(),
      "officeTimeOutLocation": officeTimeOutLocation?.toJson(),
      "permissionTimeIn": permissionTimeIn?.toIso8601String(),
      "permissionTimeInLocation": permissionTimeInLocation?.toJson(),
      "permissionTimeOut": permissionTimeOut?.toIso8601String(),
      "permissionTimeOutLocation": permissionTimeOutLocation?.toJson(),
      "status": status,
      "tallyAttendanceStatus": tallyAttendanceStatus?.toString(),
      "tallyPermissionStatus": tallyPermissionStatus?.toString()
    };
  }
}
