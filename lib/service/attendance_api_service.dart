import 'dart:convert';
import 'package:attendance_app/modals/mark_attendance_data.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AttendanceApiService {
  final String baseUrl;

  AttendanceApiService({
    required this.baseUrl,
  });

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // -------------------------------
  // TOKEN
  // -------------------------------
  Future<String?> _getToken() async {
    return await _storage.read(key: "jwt_token");
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();

    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // -------------------------------
  // CREATE Attendance Master
  // POST /api/v1/attendance-masters
  // -------------------------------
  Future<Map<String, dynamic>> createAttendance({
    required Map<String, dynamic> requestBody,
  }) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters");

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(requestBody),
    );

    return _handleResponse(response);
  }

  // -------------------------------
  // MARK Attendance
  // POST /api/v1/attendance-masters/mark
  // -------------------------------
  Future<Map<String, dynamic>> markAttendance({
    required Map<String, dynamic> requestBody,
  }) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/mark");

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(requestBody),
    );

    return _handleResponse(response);
  }

  // -------------------------------
  // GET BY ID
  // GET /api/v1/attendance-masters/{id}
  // -------------------------------
  Future<Map<String, dynamic>> getById(int id) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/$id");

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    return _handleResponse(response);
  }

  // -------------------------------
  // GET TODAY ATTENDANCE
  // GET /api/v1/attendance-masters/today/{employeeName}
  // -------------------------------
  Future<Map<String, dynamic>> getTodayAttendance(String employeeName) async {
    final url = Uri.parse(
      "$baseUrl/api/v1/attendance-masters/today/$employeeName",
    );

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    return _handleResponse(response);
  }

  // -------------------------------
  // SEARCH BY MOBILE AND DATE
  // GET /api/v1/attendance-masters/search-by-mobile-number-and-date
  // -------------------------------
  Future<MarkAttendanceData?> getAttendanceByMobileAndDate({
    required String mobileNumber,
    required String date,
  }) async {
    final url = Uri.parse(
      "$baseUrl/api/v1/attendance-masters/search-by-mobile-number-and-date",
    ).replace(queryParameters: {
      'mobileNumber': mobileNumber,
      'date': date,
    });

    final response = await http.get(url, headers: await _headers());

    final decoded = _handleResponse(response);

    if (decoded == null) return null;

    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // GET ALL
  // GET /api/v1/attendance-masters
  // -------------------------------
  Future<List<MarkAttendanceData>> getAllAttendance() async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters");

    final response = await http.get(
      url,
      headers: await _headers(),
    );

    final decoded = _handleResponse(response);

    // 🔥 IMPORTANT: convert JSON list → model list
    return (decoded as List)
        .map((e) => MarkAttendanceData.fromJson(e))
        .toList();
  }

  // -------------------------------
  // UPDATE
  // PUT /api/v1/attendance-masters/{id}
  // -------------------------------
  Future<Map<String, dynamic>> updateAttendance({
    required int id,
    required Map<String, dynamic> requestBody,
  }) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/$id");

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(requestBody),
    );

    return _handleResponse(response);
  }

  // -------------------------------
  // UPDATE BY MOBILE AND DATE
  // PUT /api/v1/attendance-masters/update-by-mobile-and-date
  // -------------------------------
  Future<MarkAttendanceData> updateAttendanceByMobileAndDate({
    required String mobileNumber,
    required String date,
    required Map<String, dynamic> requestBody,
  }) async {
    final url = Uri.parse(
      "$baseUrl/api/v1/attendance-masters/update-attendance-by-mobile-number-and-date",
    ).replace(queryParameters: {
      'mobileNumber': mobileNumber,
      'selectedDate': date,
    });

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(requestBody),
    );

    final decoded = _handleResponse(response);

    return MarkAttendanceData.fromJson(decoded);
  }

  // -------------------------------
  // DELETE
  // DELETE /api/v1/attendance-masters/{id}
  // -------------------------------
  Future<void> deleteAttendance(int id) async {
    final url = Uri.parse("$baseUrl/api/v1/attendance-masters/$id");

    final response = await http.delete(
      url,
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded["message"] ?? "Delete failed");
    }
  }

  // -------------------------------
  // RESPONSE HANDLER
  // -------------------------------
  dynamic _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      throw Exception(
        decoded["message"] ?? "API Error (${response.statusCode})",
      );
    }
  }
}
