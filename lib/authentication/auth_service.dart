import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = "http://192.168.1.2:8080";

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // LOGIN
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save JWT Token
        await saveToken(data['token']);

        return data;
      } else {
        throw Exception(
          'Login Failed: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network Error: $e');
    }
  }

  // SAVE TOKEN
  static Future<void> saveToken(String token) async {
    await _storage.write(
      key: 'jwt_token',
      value: token,
    );
  }

  // GET TOKEN
  static Future<String?> getToken() async {
    return await _storage.read(
      key: 'jwt_token',
    );
  }

  // LOGOUT
  static Future<void> logout() async {
    await _storage.delete(
      key: 'jwt_token',
    );
  }

  // CHECK LOGIN
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
