import 'package:attendance_app/authentication/auth_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final FirebaseFirestore _firestore;

  AuthRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserData> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User document not found');
    }

    final data = doc.data()!;
    return UserData(
      uid: uid,
      username: data['username'] as String?,
      email: data['email'] as String?,
      employeeId: data['employee_id'] as String?,
      mobileNumber: data['mobile_number'] as String?,
      isAdmin: data['isAdmin'] ?? false,
      isExceptTimeIn: data['isExceptTimeIn'] ?? false,
    );
  }

  Future<void> createUserRecord(
      {required String uid,
      required String username,
      required String email,
      required String employeeId,
      required String mobileNumber,
      bool isAdmin = false,
      bool isExceptTimeIn = false}) async {
    await _firestore.collection('users').doc(uid).set({
      'username': username,
      'email': email,
      'employee_id': employeeId,
      'mobile_number': mobileNumber,
      'isAdmin': isAdmin,
      'isExceptTimeIn': isExceptTimeIn,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserRecord(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}
