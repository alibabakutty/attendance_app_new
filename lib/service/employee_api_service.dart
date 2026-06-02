import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:attendance_app/modals/employee_master_data.dart';

class EmployeeApiService {
  String get _url {
    final base =
        dotenv.get('API_BASE_URL', fallback: 'http://192.168.1.3:8080');
    return '$base/api/v1/employee-masters';
  }

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // CREATE
  Future<bool> createEmployee(EmployeeMasterData employee, String token) async {
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: _getHeaders(token),
        body: jsonEncode(employee.toJson()),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("CREATE ERROR: $e");
      return false;
    }
  }

  // BULK UPLOAD EXCEL
  Future<bool> bulkUploadEmployees(File excelFile, String token) async {
    try {
      final uri = Uri.parse('$_url/bulk-upload');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('file', excelFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("BULK UPLOAD ERROR: $e");
      return false;
    }
  }

  // GET ALL EMPLOYEES
  Future<List<EmployeeMasterData>> getAllEmployees(String token) async {
    try {
      final response = await http.get(
        Uri.parse(_url),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((emp) => EmployeeMasterData.fromJson(emp)).toList();
      }
      return [];
    } catch (e) {
      print('FETCH ALL ERROR: $e');
      return [];
    }
  }

  // GET BY MOBILE NUMBER
  Future<EmployeeMasterData?> getEmployeeByMobileNumber(
      String mobileNumber, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_url/mobile/$mobileNumber'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return EmployeeMasterData.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print("FETCH BY MOBILE ERROR: $e");
      return null;
    }
  }

  // UPDATE BY MOBILE NUMBER
  Future<bool> updateEmployee(
      String mobileNumber, EmployeeMasterData employee, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$_url/mobile/$mobileNumber'),
        headers: _getHeaders(token),
        body: jsonEncode(employee.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("UPDATE ERROR: $e");
      return false;
    }
  }

  // DELETE BY EMPLOYEE ID
  Future<bool> deleteEmployee(String employeeId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$_url/$employeeId'),
        headers: _getHeaders(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("DELETE ERROR: $e");
      return false;
    }
  }
}
