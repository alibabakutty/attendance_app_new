class MarkAttendanceData {
  final String employeeId;
  final String employeeName;
  final String? mobileNumber;
  final DateTime? attendanceDate;
  final String? siteName;
  final DateTime? officeTimeIn;
  final DateTime? officeTimeOut;
  final String status;

  MarkAttendanceData({
    required this.employeeId,
    required this.employeeName,
    this.mobileNumber,
    this.attendanceDate,
    this.siteName,
    this.officeTimeIn,
    this.officeTimeOut,
    required this.status,
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
      officeTimeOut: json['officeTimeOut'] != null
          ? DateTime.parse(json['officeTimeOut'])
          : null,
      status: json['status'] ?? 'ABSENT',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "employeeId": employeeId,
      "employeeName": employeeName,
      "mobileNumber": mobileNumber,
      "attendanceDate": attendanceDate?.toIso8601String().split('T')[0],
      "siteName": siteName,
      "status": status,
    };
  }
}
