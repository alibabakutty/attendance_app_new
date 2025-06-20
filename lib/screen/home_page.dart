import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:attendance_app/screen/admin_manage_dashboard.dart';
import 'package:attendance_app/screen/attendance_history.dart';
import 'package:attendance_app/screen/employee_profiles.dart';
import 'package:attendance_app/screen/mark_attendance.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color backgroundColor = Color(0xFF273F4F);
const Color textPrimary = Color(0xFFF1F2F6);
const Color textSecondary = Color(0xFFB0BEC5);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _onLogout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // final isAdmin = authProvider.isAdmin;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF37474F),
        title: const Text('Logout', style: TextStyle(color: Colors.cyanAccent)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: textPrimary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.cyanAccent),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              authProvider.logout();
              Navigator.of(context).pushReplacementNamed(
                '/employeeLogin',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
    bool adminOnly = false,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (adminOnly && !authProvider.isAdmin) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin access required'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              onTap();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Icon(icon, size: 36, color: Colors.white),
                    if (adminOnly && !authProvider.isAdmin)
                      Positioned(
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (adminOnly && !authProvider.isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Admin Only',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        title: Text(
          authProvider.isAdmin ? 'Admin Dashboard' : 'Employee Dashboard',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.cyanAccent,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _onLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${authProvider.username} 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                authProvider.isAdmin
                    ? 'Administrator privileges enabled'
                    : 'Let\'s do something amazing today!',
                style: const TextStyle(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.9,
                  children: [
                    _buildDashboardCard(
                      icon: Icons.access_time,
                      title: 'Mark Attendance',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => _navigateTo(const MarkAttendance()),
                    ),
                    _buildDashboardCard(
                      icon: Icons.history,
                      title: 'Attendance History',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6FD8), Color(0xFFFF9A8B)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      onTap: () => _navigateTo(const AttendanceHistory()),
                    ),
                    _buildDashboardCard(
                      icon: Icons.person_outline,
                      title: 'Employee Profile',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF43CBFF), Color(0xFF9708CC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () => _navigateTo(const EmployeeProfiles()),
                    ),
                    _buildDashboardCard(
                      icon: Icons.settings,
                      title: 'Admin Management',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBDA61), Color(0xFFFF5ACD)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      onTap: () => _navigateTo(const AdminManageDashboard()),
                      adminOnly: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
