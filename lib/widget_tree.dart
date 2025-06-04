import 'package:attendance_app/authentication/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndRedirect();
    });
  }

  Future<void> _checkAuthAndRedirect() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initializationDone; // Add this to your AuthProvider

      if (!mounted) return;

      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, stackTrace) {
      debugPrint("Redirect error: $e");
      debugPrint(stackTrace.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading ||
        (authProvider.currentUser == null && authProvider.isLoggedIn)) {
      return _buildLoadingScreen();
    }

    if (authProvider.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
      return _buildLoadingScreen();
    }

    return _buildLoginScreen(context);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLoginScreen(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAppHeader(),
                const SizedBox(height: 50),
                _buildLoginCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Column(
      children: [
        const Icon(Icons.fingerprint, size: 80, color: Colors.white),
        const SizedBox(height: 20),
        const Text(
          'Cloud9 Attendance',
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const Text(
          'Management System',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLoginButton(
            context,
            text: 'ADMIN LOGIN',
            onPressed: () => Navigator.pushNamed(context, '/adminLogin'),
            isPrimary: true,
          ),
          const SizedBox(height: 15),
          _buildDividerWithText('OR'),
          const SizedBox(height: 15),
          _buildLoginButton(
            context,
            text: 'EMPLOYEE LOGIN',
            onPressed: () => Navigator.pushNamed(context, '/employeeLogin'),
            isPrimary: false,
          ),
          const SizedBox(height: 20),
          _buildVersionText(),
        ],
      ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context, {
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : const Color(0xFF2193b0),
          foregroundColor: isPrimary ? const Color(0xFF2193b0) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: Colors.white54, width: 1),
          ),
          elevation: 3,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDividerWithText(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white30, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            text,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: Colors.white30, thickness: 1)),
      ],
    );
  }

  Widget _buildVersionText() {
    return Text(
      'Version 1.0.0',
      style: TextStyle(color: Colors.white70, fontSize: 12),
    );
  }
}
