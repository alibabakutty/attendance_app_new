import 'package:intl/intl.dart';

class GeoPointData {
  final double latitude;
  final double longitude;

  GeoPointData({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPointData.fromJson(Map<String, dynamic> json) {
    return GeoPointData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class EmployeeLocationData {
  final String siteName;
  final GeoPointData officeTimeInLocation;
  final GeoPointData officeTimeOutLocation;

  EmployeeLocationData({
    required this.siteName,
    required this.officeTimeInLocation,
    required this.officeTimeOutLocation,
  });

  factory EmployeeLocationData.fromJson(Map<String, dynamic> json) {
    return EmployeeLocationData(
      siteName: json['siteName'] ?? '',
      officeTimeInLocation:
          GeoPointData.fromJson(json['officeTimeInLocation'] ?? {}),
      officeTimeOutLocation:
          GeoPointData.fromJson(json['officeTimeOutLocation'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteName': siteName,
      'officeTimeInLocation': officeTimeInLocation.toJson(),
      'officeTimeOutLocation': officeTimeOutLocation.toJson(),
    };
  }
}

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
  final List<EmployeeLocationData> locations;

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
    required this.locations,
  });

  // FROM API RESPONSE
  factory EmployeeMasterData.fromJson(Map<String, dynamic> json) {
    var locationsList = json['locations'] as List?;
    List<EmployeeLocationData> parsedLocations = locationsList != null
        ? locationsList
            .map((loc) => EmployeeLocationData.fromJson(loc))
            .toList()
        : [];

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
      locations: parsedLocations,
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
      "locations": locations.map((loc) => loc.toJson()).toList(),
    };
  }
}
