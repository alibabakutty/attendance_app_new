import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeMasterData {
  final String employeeId;
  final String employeeName;
  final String mobileNumber;
  final Timestamp dateOfJoining;
  final String aadhaarNumber;
  final String panNumber;
  final String email;
  final String password;
  final Timestamp createdAt;

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
  });

  // convert data from Firestore to EmployeeMasterData object
  factory EmployeeMasterData.fromFirestore(Map<String, dynamic> data) {
    return EmployeeMasterData(
      employeeId: data['employee_id'] ?? '',
      employeeName: data['employee_name'] ?? '',
      mobileNumber: data['mobile_number'] ?? '',
      dateOfJoining: data['date_of_joining'] ?? Timestamp.now(),
      aadhaarNumber: data['aadhaar_number'] ?? '',
      panNumber: data['pan_number'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      createdAt: data['created_at'] ?? Timestamp.now(),
    );
  }

  // convert EmployeeMasterData object to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'mobile_number': mobileNumber,
      'date_of_joining': dateOfJoining,
      'aadhaar_number': aadhaarNumber,
      'pan_number': panNumber,
      'email': email,
      'password': password,
      'created_at': createdAt,
    };
  }
}
