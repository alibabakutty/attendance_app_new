import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/firebase_options.dart';
import 'package:attendance_app/screen/admin_manage_dashboard.dart';
import 'package:attendance_app/screen/attendance_history.dart';
import 'package:attendance_app/screen/delete_account_page.dart';
import 'package:attendance_app/screen/employee_login_page.dart';
import 'package:attendance_app/screen/employee_master.dart';
import 'package:attendance_app/screen/employee_profiles.dart';
import 'package:attendance_app/screen/home_page.dart';
import 'package:attendance_app/screen/admin_login_page.dart';
import 'package:attendance_app/screen/mark_attendance.dart';
import 'package:attendance_app/widget_tree.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).catchError((error) {
    // Add error handling here if needed
    debugPrint('Firebase initialization error: $error');
    throw Exception('Failed to initialize Firebase: $error');
  });
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Cloud9 Attendance Management',
        theme: ThemeData(primarySwatch: Colors.blue),
        routes: {
          '/': (context) => const WidgetTree(),
          '/adminLogin': (context) => const AdminLoginPage(),
          '/employeeLogin': (context) => const EmployeeLoginPage(),
          '/home': (context) => const HomePage(),
          '/employeeProfiles': (context) => const EmployeeProfiles(),
          '/employeeMaster': (context) => const EmployeeMaster(),
          '/markAttendance': (context) => const MarkAttendance(),
          '/attendanceHistory': (context) => const AttendanceHistory(),
          '/adminManageDashboard': (context) => const AdminManageDashboard(),
          '/deleteAccount': (context) => const DeleteAccountPage(),
        },
      ),
    );
  }
}
