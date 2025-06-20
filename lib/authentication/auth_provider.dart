import 'dart:async';

import 'package:attendance_app/authentication/auth.utils.dart';
import 'package:attendance_app/authentication/auth_exceptions.dart';
import 'package:attendance_app/authentication/auth_models.dart';
import 'package:attendance_app/authentication/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final Completer<void> _initializationCompleter = Completer<void>();

  User? _currentUser;
  UserData? _userData;
  String? _errorMessage;
  bool _isLoading = false;
  DateTime? _sessionExpiry;
  late SharedPreferences _prefs;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  Future<void> get initializationDone => _initializationCompleter.future;

  // Getters
  bool get isEmployee => _userData?.isAdmin == false;
  bool get isAdmin => _userData?.isAdmin ?? false;
  bool get isLoggedIn => _currentUser != null;
  String? get username => _userData?.username;
  String? get email => _userData?.email;
  String? get employeeId => _userData?.employeeId;
  String? get mobileNumber => _userData?.mobileNumber;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  DateTime? get sessionExpiry => _sessionExpiry;
  bool get isExceptTimeIn => _userData?.isExceptTimeIn ?? false;

  Future<void> _init() async {
    await _loadSession();
    _setupAuthListener();

    if (isLoggedIn && _currentUser != null) {
      await _validateAndRefreshSession();
    }
    _initializationCompleter.complete();
  }

  Future<void> _validateAndRefreshSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _currentUser!.reload();
      final freshUser = _authService.currentUser;

      if (freshUser == null) {
        await _clearSession();
        return;
      }

      final token = await freshUser.getIdToken(true);
      if (JwtDecoder.isExpired(token!)) {
        await _clearSession();
        return;
      }
      await _loadUserData(freshUser.uid);
    } catch (e) {
      await _clearSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupAuthListener() {
    _authService.authStateChanges.listen((User? user) async {
      _currentUser = user;
      if (user != null) {
        await _loadUserData(user.uid);
        await _saveSession();
      } else {
        await _clearSession();
      }
      notifyListeners();
    });
  }

  Future<void> _loadSession() async {
    _prefs = await SharedPreferences.getInstance();
    _sessionExpiry =
        _prefs.getString('sessionExpiry')?.let((s) => DateTime.parse(s));
  }

  Future<void> _saveSession() async {
    _sessionExpiry = DateTime.now().add(Duration(days: 7));
    await _prefs.setString('sessionExpiry', _sessionExpiry!.toIso8601String());
  }

  Future<void> _clearSession() async {
    await _prefs.clear();
    _currentUser = null;
    _errorMessage = null;
    _sessionExpiry = null;
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();

      _userData = await _authService.getUserData(uid);
      await _saveSession();
    } catch (e) {
      _errorMessage = 'Failed to load user data';
      await _clearSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithEmail(
      {required String email, required String password}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.signIn(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAccount({
    required String username,
    required String email,
    required String password,
    required String employeeId,
    required String mobileNumber,
    bool isAdmin = false,
    bool isExceptTimeIn = false,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.createNewAccount(
        username: username,
        email: email,
        password: password,
        employeeId: employeeId,
        mobileNumber: mobileNumber,
        isAdmin: isAdmin,
        isExceptTimeIn: isExceptTimeIn,
      );
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _authService.signOut();
      await _clearSession();
    } catch (e) {
      _errorMessage = 'Logout failed';
    }
  }

  Future<bool> deleteAccount({required String currentPassword}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.deleteAccount(currentPassword: currentPassword);
      await _clearSession();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
