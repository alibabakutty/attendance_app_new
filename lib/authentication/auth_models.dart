class UserData {
  final String uid;
  final String? username;
  final String? email;
  final String? employeeId;
  final String? mobileNumber;
  final bool isAdmin;
  final bool isExceptTimeIn;

  UserData({
    required this.uid,
    this.username,
    this.email,
    this.employeeId,
    this.mobileNumber,
    this.isAdmin = false,
    this.isExceptTimeIn = false,
  });
}
