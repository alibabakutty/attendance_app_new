import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Completer<void> _initializationCompleter = Completer<void>();

  String? _token;
  String? _employeeId;
  String? _username;
  String? _role;
  String? _mobileNumber;
  String? _employeeImageData;
  Uint8List? _employeeImageBytes;
  String? _errorMessage;

  bool _isLoading = false;
  bool _isInitialized = false;
  DateTime? _expiryDate;
  Timer? _authTimer;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

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
  String? get errorMessage => _errorMessage;
  DateTime? get expiryDate => _expiryDate;
  Uint8List? get employeeImageBytes => _employeeImageBytes;

  // =========================
  // INIT
  // =========================

  Future<void> _init() async {
    try {
      await _loadSession();
    } catch (e) {
      debugPrint('Initialization Session Recovery Failure: $e');
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
      _employeeId = response['userEmployeeId']?.toString();
      _mobileNumber = response['mobileNumber']?.toString() ??
          response['mobile_number']?.toString();

      if (_token == null || _token!.isEmpty) {
        throw const FormatException(
            'Authentication token was missing from server response.');
      }

      // Safe Extraction and Processing of Images
      _employeeImageData = response['userImageData']?.replaceFirst(
        'data:image/jpeg;base64,',
        '',
      );
      _processImageBytes();

      // Decode and handle Token Expiring Lifecycles
      final decodedToken = JwtDecoder.decode(_token!);
      if (decodedToken.containsKey('exp')) {
        _expiryDate =
            DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
        _setAutoLogoutTimer();
      }

      await _saveSession();
      return true;
    } on FormatException catch (fe) {
      _errorMessage = fe.message;
      return false;
    } catch (e) {
      debugPrint('Login Error Stacktrace: $e');
      // Friendly, generic filter covering backend issues gracefully
      _errorMessage =
          'Invalid credentials or server unreachable. Please check your inputs for correct credentials.';
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
      _token = await _storage.read(key: 'jwt_token');
      if (_token == null || isTokenExpired()) {
        await logout();
        return;
      }

      _username = await _storage.read(key: 'username');
      _role = await _storage.read(key: 'role');
      _employeeId = await _storage.read(key: 'employeeId');
      _mobileNumber = await _storage.read(key: 'mobileNumber');
      _employeeImageData = await _storage.read(key: 'employeeImageData');

      _processImageBytes();

      final decoded = JwtDecoder.decode(_token!);
      if (decoded.containsKey('exp')) {
        _expiryDate =
            DateTime.fromMillisecondsSinceEpoch(decoded['exp'] * 1000);
        _setAutoLogoutTimer();
      }

      debugPrint('User persistent session verified and active.');
    } catch (e) {
      debugPrint('Session Restoring Engine Corrupted: $e');
      await logout();
    }
  }

  // =========================
  // SAVE SESSION
  // =========================

  Future<void> _saveSession() async {
    await _storage.write(key: 'jwt_token', value: _token);
    await _storage.write(key: 'username', value: _username);
    await _storage.write(key: 'role', value: _role);
    await _storage.write(key: 'employeeId', value: _employeeId);
    await _storage.write(key: 'mobileNumber', value: _mobileNumber);
    if (_employeeImageData != null) {
      await _storage.write(key: 'employeeImageData', value: _employeeImageData);
    }
  }

  // =========================
  // LOGOUT
  // =========================

  Future<void> logout() async {
    try {
      _cancelLogoutTimer();

      _token = null;
      _username = null;
      _role = null;
      _employeeImageData = null;
      _employeeId = null;
      _mobileNumber = null;
      _expiryDate = null;
      _errorMessage = null;

      await _storage.deleteAll();
    } catch (e) {
      debugPrint(
        'Logout Error: $e',
      );
    } finally {
      notifyListeners();
    }
  }

  // =========================
  // HELPERS
  // =========================
  // =========================
  // TOKEN VALIDATION
  // =========================

  bool isTokenExpired() {
    if (_token == null) return true;
    try {
      return JwtDecoder.isExpired(_token!);
    } catch (_) {
      return true; // If token format is somehow broken, treat as expired
    }
  }

  void _processImageBytes() {
    if (_employeeImageData == null || _employeeImageData!.isEmpty) {
      _employeeImageBytes = null;
      return;
    }
    try {
      _employeeImageBytes = base64Decode(_employeeImageData!);
    } catch (e) {
      debugPrint('Cached image compilation failure: $e');
      _employeeImageBytes = null;
    }
  }

  void _setAutoLogoutTimer() {
    _cancelLogoutTimer();
    if (_expiryDate == null) return;

    final timeToExpiry = _expiryDate!.difference(DateTime.now()).inSeconds;
    if (timeToExpiry > 0) {
      _authTimer = Timer(Duration(seconds: timeToExpiry), () {
        debugPrint(
            'Token expiration deadline reached. Executing automated forced logout.');
        logout();
      });
    } else {
      logout();
    }
  }

  void _cancelLogoutTimer() {
    _authTimer?.cancel();
    _authTimer = null;
  }

  // =========================
  // AUTH HEADERS
  // =========================

  Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  @override
  void dispose() {
    _cancelLogoutTimer();
    super.dispose();
  }
}
