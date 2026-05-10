import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final Completer<void> _initializationCompleter = Completer<void>();

  String? _token;
  String? _employeeId;
  String? _username;
  String? _role;
  String? _mobileNumber;
  String? _employeeImageData;
  String? _errorMessage;

  bool _isLoading = false;
  bool _isInitialized = false;

  DateTime? _expiryDate;

  Future<void> get initializationDone => _initializationCompleter.future;

  // =========================
  // GETTERS
  // =========================

  bool get isLoggedIn => _token != null && !JwtDecoder.isExpired(_token!);

  bool get isAdmin => _role == 'ADMIN';

  bool get isEmployee => _role == 'EMPLOYEE';

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  String? get token => _token;

  String? get employeeId => _employeeId;

  String? get username => _username;

  String? get mobileNumber => _mobileNumber;

  String? get role => _role;

  String? get employeeImageData => _employeeImageData;

  String? get errorMessage => _errorMessage;

  DateTime? get expiryDate => _expiryDate;

  // Decoded image bytes for UI
  Uint8List? get employeeImageBytes {
    if (_employeeImageData == null || _employeeImageData!.isEmpty) {
      return null;
    }

    try {
      return base64Decode(_employeeImageData!);
    } catch (e) {
      debugPrint('Image decode error: $e');
      return null;
    }
  }

  // =========================
  // INIT
  // =========================

  Future<void> _init() async {
    try {
      await _loadSession();
    } catch (e) {
      debugPrint('Init Error: $e');
    } finally {
      _isInitialized = true;

      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }

      notifyListeners();
    }
  }

  // =========================
  // LOGIN
  // =========================

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.login(
        username: username,
        password: password,
      );

      _token = response['token'];
      _username = response['username'];
      _role = response['role'];
      _employeeId = response['employeeId'];
      _mobileNumber = response['mobileNumber'];

      // FIXED: use correct key from backend
      _employeeImageData = response['userImageData']?.replaceFirst(
        'data:image/jpeg;base64,',
        '',
      );

      debugPrint(
        'Image exists: ${_employeeImageData != null}',
      );

      debugPrint(
        'Image length: ${_employeeImageData?.length}',
      );

      if (_token == null || _token!.isEmpty) {
        throw Exception('Token is missing');
      }

      final decodedToken = JwtDecoder.decode(
        _token!,
      );

      if (decodedToken.containsKey('exp')) {
        _expiryDate = DateTime.fromMillisecondsSinceEpoch(
          decodedToken['exp'] * 1000,
        );
      }

      await _saveSession();

      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = e.toString();

      debugPrint(
        'Login Error: $e',
      );

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================
  // LOAD SESSION
  // =========================

  Future<void> _loadSession() async {
    try {
      _token = await _storage.read(
        key: 'jwt_token',
      );

      _username = await _storage.read(
        key: 'username',
      );

      _role = await _storage.read(
        key: 'role',
      );

      _employeeImageData = await _storage.read(
        key: 'employeeImageData',
      );

      _employeeId = await _storage.read(
        key: 'employeeId',
      );

      _mobileNumber = await _storage.read(
        key: 'mobileNumber',
      );

      if (_token == null) {
        return;
      }

      final isExpired = JwtDecoder.isExpired(
        _token!,
      );

      if (isExpired) {
        await logout();
        return;
      }

      final decoded = JwtDecoder.decode(
        _token!,
      );

      if (decoded.containsKey('exp')) {
        _expiryDate = DateTime.fromMillisecondsSinceEpoch(
          decoded['exp'] * 1000,
        );
      }

      debugPrint(
        'Session restored successfully',
      );
    } catch (e) {
      debugPrint(
        'Load Session Error: $e',
      );

      await logout();
    }
  }

  // =========================
  // SAVE SESSION
  // =========================

  Future<void> _saveSession() async {
    await _storage.write(
      key: 'jwt_token',
      value: _token,
    );

    await _storage.write(
      key: 'username',
      value: _username,
    );

    await _storage.write(
      key: 'role',
      value: _role,
    );

    if (_employeeImageData != null) {
      await _storage.write(
        key: 'employeeImageData',
        value: _employeeImageData,
      );
    }

    await _storage.write(
      key: 'employeeId',
      value: _employeeId,
    );

    await _storage.write(
      key: 'mobileNumber',
      value: _mobileNumber,
    );
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    try {
      _token = null;
      _username = null;
      _role = null;
      _employeeImageData = null;
      _employeeId = null;
      _mobileNumber = null;
      _expiryDate = null;
      _errorMessage = null;

      await _storage.deleteAll();

      notifyListeners();
    } catch (e) {
      debugPrint(
        'Logout Error: $e',
      );
    }
  }

  // =========================
  // TOKEN VALIDATION
  // =========================

  bool isTokenExpired() {
    if (_token == null) {
      return true;
    }

    return JwtDecoder.isExpired(
      _token!,
    );
  }

  // =========================
  // AUTH HEADERS
  // =========================

  Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }
}
