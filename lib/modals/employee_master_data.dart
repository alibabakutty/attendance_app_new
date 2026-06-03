import 'package:intl/intl.dart';

class EmployeeMasterData {
  final String employeeId;
  final String employeeName;
  final String mobileNumber;
  final DateTime? dateOfJoining;
  final String aadhaarNumber;
  final String panNumber;
  final String email;
  final String password;
  final DateTime? createdAt;
  final String? employeeImageData;

  EmployeeMasterData({
    required this.employeeId,
    required this.employeeName,
    required this.mobileNumber,
    required this.dateOfJoining,
    required this.aadhaarNumber,
    required this.panNumber,
    required this.email,
    required this.password,
    required this.createdAt,
    required this.employeeImageData,
  });

  // FROM API RESPONSE
  factory EmployeeMasterData.fromJson(Map<String, dynamic> json) {
    return EmployeeMasterData(
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      mobileNumber: json['mobileNumber'] ?? '',
      dateOfJoining: json['dateOfJoining'] != null
          ? DateTime.parse(json['dateOfJoining'])
          : null,
      aadhaarNumber: json['aadhaarNumber'] ?? '',
      panNumber: json['panNumber'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      employeeImageData: json['employeeImageData'],
    );
  }

  // TO API REQUEST
  Map<String, dynamic> toJson() {
    return {
      "employeeId": employeeId,
      "employeeName": employeeName,
      "mobileNumber": mobileNumber,
      'dateOfJoining': dateOfJoining != null
          ? DateFormat('yyyy-MM-dd').format(dateOfJoining!)
          : null,
      "aadhaarNumber": aadhaarNumber,
      "panNumber": panNumber,
      "email": email,
      "password": password,
      "createdAt": createdAt?.toIso8601String(),
      "employeeImageData": employeeImageData,
    };
  }
}
