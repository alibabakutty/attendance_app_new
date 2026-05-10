import 'package:attendance_app/modals/employee_master_data.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmployeeApiService {
  // Emulator
  // static const String baseUrl = 'http://10.0.2.2:8080/api/v1/employee-masters';

  // Real Device
  static const String baseUrl =
      'http://192.168.1.3:8080/api/v1/employee-masters';

  // CREATE
  Future<bool> createEmployee(
    EmployeeMasterData employee,
    String token,
  ) async {
    try {
      final requestBody = jsonEncode(employee.toJson());

      print("===== REQUEST URL =====");
      print(baseUrl);

      print("===== TOKEN =====");
      print(token);

      print("===== REQUEST BODY =====");
      print(requestBody);

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      print("===== RESPONSE STATUS =====");
      print(response.statusCode);

      print("===== RESPONSE BODY =====");
      print(response.body);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("===== ERROR =====");
      print(e);
      return false;
    }
  }

  // GET ALL EMPLOYEES
  Future<List<EmployeeMasterData>> getAllEmployees() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        return data
            .map(
              (employee) => EmployeeMasterData.fromJson(employee),
            )
            .toList();
      }

      return [];
    } catch (e) {
      print('Error fetching employees: $e');

      return [];
    }
  }

  // GET BY MOBILE NUMBER
  Future<EmployeeMasterData?> getEmployeeByMobileNumber(
      String mobileNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mobile/$mobileNumber'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return EmployeeMasterData.fromJson(data);
      }

      return null;
    } catch (e) {
      print(e);

      return null;
    }
  }

  // UPDATE
  Future<bool> updateEmployee(
      String mobileNumber, EmployeeMasterData employee) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/mobile/$mobileNumber'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(employee.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      print(e);

      return false;
    }
  }

  // DELETE
  Future<bool> deleteEmployee(String employeeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$employeeId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print(e);

      return false;
    }
  }
}
