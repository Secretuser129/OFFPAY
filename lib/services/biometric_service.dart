import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyUseBiometricsForAppLock = 'offpay_biometrics_app_lock';
const String _keyUseBiometricsForTransfers = 'offpay_biometrics_transfers';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device has biometric hardware and is enrolled
  static Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) return false;

      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Trigger the biometric authentication dialog
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  // --- User Preferences ---

  static Future<bool> isAppLockBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseBiometricsForAppLock) ?? false;
  }

  static Future<void> setAppLockBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseBiometricsForAppLock, enabled);
  }

  static Future<bool> isTransferBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseBiometricsForTransfers) ?? false;
  }

  static Future<void> setTransferBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseBiometricsForTransfers, enabled);
  }
}
