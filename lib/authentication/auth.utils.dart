import 'package:shared_preferences/shared_preferences.dart';

extension StringExtensions on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

extension DateTimeExtensions on DateTime {
  String toIso8601String() => toUtc().toIso8601String();
}

extension ShredPreferencesExtensions on SharedPreferences {
  Future<void> clearSession() async {
    await remove('sessionExpiry');
  }
}

extension NullableStringExtensions on String? {
  T? let<T>(T Function(String) block) => this == null ? null : block(this!);
}
