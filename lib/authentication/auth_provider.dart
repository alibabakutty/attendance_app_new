import 'dart:async';

import 'package:attendance_app/authentication/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final Auth _auth;
  User? _currentUser;
  bool _isAdmin = false;
  bool _isEmployee = false;
  bool _isLoggedIn = false;
  String? _username;
  String? _email;
  String? _employeeId;
  String? _mobileNumber;
  String? _errorMessage;
  bool _isLoading = false;
  DateTime? _sessionExpiry;
  late SharedPreferences _prefs;

  AuthProvider({Auth? auth}) : _auth = auth ?? Auth() {
    _setupTokenRefresh();
    _initAuthState();
  }

  final Completer<void> _initializationCompleter = Completer<void>();
  Future<void> get initializationDone => _initializationCompleter.future;

  // Getters
  bool get isEmployee => _isEmployee;
  bool get isAdmin => _isAdmin;
  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get email => _email;
  String? get employeeId => _employeeId;
  String? get mobileNumber => _mobileNumber;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  DateTime? get sessionExpiry => _sessionExpiry;

  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _loadSession();

      if (_isLoggedIn && _currentUser != null) {
        try {
          // Force-refresh the Firebase Auth token to check validity
          await _currentUser!.reload();
          final freshUser = FirebaseAuth.instance.currentUser;

          // If currentUser became null after reload (shouldn't happen but defensive programming)
          if (freshUser == null) {
            await _clearSession();
            _initializationCompleter.complete(); // Add this
            return;
          }

          // Get fresh token to ensure it's valid
          final token = await freshUser.getIdToken(true);

          // Verify token is not expired
          final decodedToken = JwtDecoder.decode(token!);
          if (decodedToken['exp'] * 1000 <
              DateTime.now().millisecondsSinceEpoch) {
            await _clearSession();
            _initializationCompleter.complete();
            return;
          }

          // Check if user exists in Firestore with timeout
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(freshUser.uid)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 10));

          if (!userDoc.exists) {
            await _clearSession();
            _initializationCompleter.complete(); // Add this
            return;
          }

          // Load fresh user data with timeout
          await _loadUserData(
            freshUser.uid,
          ).timeout(const Duration(seconds: 10));
        } on FirebaseAuthException catch (e) {
          debugPrint(
            'Auth error during initialization: ${e.code} - ${e.message}',
          );
          await _clearSession();
        } on FirebaseException catch (e) {
          debugPrint(
            'Firestore error during initialization: ${e.code} - ${e.message}',
          );
          // Don't logout for Firestore errors - might be temporary
        } on TimeoutException {
          debugPrint('Timeout during user data refresh');
          // Don't logout for timeouts - might be network issues
        } catch (e, stackTrace) {
          debugPrint('Unexpected error during initialization: $e');
          debugPrint(stackTrace.toString());
          await _clearSession();
        }
      }
    } finally {
      // Ensure we always set loading to false
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }

      // Complete the completer when initialization is done
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  void _setupTokenRefresh() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final idToken = await user.getIdTokenResult(true);
          if (DateTime.now().isAfter(idToken.expirationTime!)) {
            await logout(); // Immediate logout if expired
          }
        } catch (e) {
          await logout(); // Fallback on error
        }
      }
    });
  }

  // Initialize auth state listener
  Future<void> _initAuthState() async {
    await _loadSession();

    _auth.authStateChanges.listen((User? user) async {
      _currentUser = user;
      if (user != null) {
        _isLoggedIn = true;
        await _loadUserData(user.uid);
        await _saveSession();
      } else {
        await _clearSession();
        _resetState();
      }
      notifyListeners();
    });
  }

  // Load saved session from SharedPreferences
  Future<void> _loadSession() async {
    _prefs = await SharedPreferences.getInstance();
    _isLoggedIn = _prefs.getBool('isLoggedIn') ?? false;
    _isAdmin = _prefs.getBool('isAdmin') ?? false;
    _isEmployee = _prefs.getBool('isEmployee') ?? false;
    _username = _prefs.getString('username');
    _email = _prefs.getString('email');
    _employeeId = _prefs.getString('employeeId');
    _mobileNumber = _prefs.getString('mobileNumber');

    final expiryString = _prefs.getString('sessionExpiry');
    if (expiryString != null) {
      _sessionExpiry = DateTime.parse(expiryString);
    } else {
      _sessionExpiry = null;
    }

    if (_isLoggedIn) {
      notifyListeners();
    }
  }

  // Save current session to SharedPreferences
  Future<void> _saveSession() async {
    _sessionExpiry = DateTime.now().add(Duration(days: 7)); // Example expiry

    await _prefs.setBool('isLoggedIn', _isLoggedIn);
    await _prefs.setBool('isAdmin', _isAdmin);
    await _prefs.setBool('isEmployee', _isEmployee);
    await _prefs.setString('username', _username ?? '');
    await _prefs.setString('email', _email ?? '');
    await _prefs.setString('employeeId', _employeeId ?? '');
    await _prefs.setString('mobileNumber', _mobileNumber ?? '');
    await _prefs.setString(
      'sessionExpiry',
      _sessionExpiry?.toIso8601String() ?? '',
    );
  }

  // Clear session data from SharedPreferences
  Future<void> _clearSession() async {
    await _prefs.remove('isLoggedIn');
    await _prefs.remove('isAdmin');
    await _prefs.remove('isEmployee');
    await _prefs.remove('username');
    await _prefs.remove('email');
    await _prefs.remove('employeeId');
    await _prefs.remove('mobileNumber');
    await _prefs.remove('sessionExpiry');
  }

  // Reset all state variables
  void _resetState() {
    _isLoggedIn = false;
    _isAdmin = false;
    _isEmployee = false;
    _username = null;
    _email = null;
    _employeeId = null;
    _mobileNumber = null;
    _errorMessage = null;
    _currentUser = null;
    _sessionExpiry = null;
  }

  // Load user data from Firestore or other sources
  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();

      _username = await _auth.getUserName(uid);
      _email = _currentUser?.email;
      _employeeId = await _auth.getUserEmployeeId(
        uid,
      ); // Assuming UID is used as employee ID
      _mobileNumber = await _auth.getEmployeeMobileNumber(uid);

      // Determine user role - you might want to fetch this from your database
      // For now using the existing flags
      _isAdmin = _isAdmin; // Preserve existing value
      _isEmployee = !_isAdmin;

      await _saveSession();
    } catch (e) {
      _errorMessage = 'Failed to load user data: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // validate current session
  // Validate current session
  Future<bool> validateSession() async {
    if (!_isLoggedIn) return false;

    try {
      // Check session expiry
      if (_sessionExpiry == null || DateTime.now().isAfter(_sessionExpiry!)) {
        await logout();
        return false;
      }

      // Verify Firebase session
      await _currentUser?.reload();
      if (_currentUser == null) {
        await logout();
        return false;
      }

      // Verify Firestore data matches
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (!userDoc.exists) {
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }

  // Refresh session data
  Future<void> refreshSession() async {
    if (_currentUser == null) return;

    try {
      await _currentUser!.reload();
      await _loadUserData(_currentUser!.uid);
      await _saveSession();
    } catch (e) {
      await logout();
      throw Exception('Session refresh failed');
    }
  }

  // Login with email and password
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Perform fresh login
      await _auth.signIn(email: email, password: password);

      // Verify the user is properly authenticated
      if (_auth.currentUser == null) {
        _errorMessage = 'Authentication failed - please try again';
        return false;
      }

      // Load user data
      await _loadUserData(_auth.currentUser!.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Authentication failed';
      return false;
    } catch (e) {
      _errorMessage = 'Unexpected error during login';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new account
  Future<bool> createAccount({
    required String username,
    required String email,
    required String password,
    required String employeeId,
    required String mobileNumber,
    bool isAdmin = false,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.createAdminAccount(
        username: username,
        email: email,
        password: password,
        employeeId: employeeId,
        mobileNumber: mobileNumber,
      );

      _isLoggedIn = true;
      _isAdmin = isAdmin;
      _isEmployee = !isAdmin;
      _username = username;
      _email = email;

      await _saveSession();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = 'Account creation failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login as guest/executive
  Future<void> loginAsExecutive() async {
    _isEmployee = true;
    _isAdmin = false;
    _isLoggedIn = true;
    _email = null;
    await _saveSession();
    notifyListeners();
  }

  // Login as admin
  Future<void> loginAsAdmin() async {
    _isEmployee = false;
    _isAdmin = true;
    _isLoggedIn = true;
    await _saveSession();
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Wipe all cached data
      _resetState();
    } catch (e) {
      print("Logout error: $e");
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Helper to get user-friendly error messages
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'token-expired':
      case 'invalid-auth-token':
        return 'Session expired. Please login again';
      default:
        return 'Authentication error: ${e.message ?? 'Unknown error'}';
    }
  }

  Future<bool> reauthenticate({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.reauthenticateWithCredential(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = 'Re-authentication failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatepassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      return await _auth.checkEmailVerified();
    } catch (e) {
      _errorMessage = 'Email verification failed: ${e.toString()}';
      return false;
    }
  }

  // modify the updateemail method
  Future<bool> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.updateEmail(
        currentPassword: currentPassword,
        newEmail: newEmail,
      );

      // Don't update local state yet - wait for verification
      // just notify user to check their email
      _errorMessage =
          'Verification email sent to $newEmail. Please verify to complete the update.';
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = 'Email update failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount({required String currentPassword}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.deleteAccount(currentPassword: currentPassword);

      // clear local state
      await _clearSession();
      _resetState();

      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getFirebaseErrorMessage(e);
      return false;
    } catch (e) {
      _errorMessage = 'Account deletion failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
