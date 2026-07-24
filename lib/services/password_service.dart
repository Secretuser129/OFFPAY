import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _balancePinKey = 'offpay_balance_pin_hash';
const _transferPinKey = 'offpay_transfer_pin_hash';

class PasswordService {
  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// SHA-256 hash a PIN string
  static String _hash(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  // ── Balance PIN ─────────────────────────────────────────────────────────

  static Future<bool> hasBalancePin() async {
    final p = await _prefs();
    final val = p.getString(_balancePinKey);
    return val != null && val.isNotEmpty;
  }

  static Future<void> setBalancePin(String pin) async {
    final p = await _prefs();
    await p.setString(_balancePinKey, _hash(pin));
  }

  static Future<bool> verifyBalancePin(String pin) async {
    final p = await _prefs();
    final stored = p.getString(_balancePinKey);
    if (stored == null || stored.isEmpty) return true; // no PIN set = free access
    return stored == _hash(pin);
  }

  static Future<void> clearBalancePin() async {
    final p = await _prefs();
    await p.remove(_balancePinKey);
  }

  // ── Transfer PIN ────────────────────────────────────────────────────────

  static Future<bool> hasTransferPin() async {
    final p = await _prefs();
    final val = p.getString(_transferPinKey);
    return val != null && val.isNotEmpty;
  }

  static Future<void> setTransferPin(String pin) async {
    final p = await _prefs();
    await p.setString(_transferPinKey, _hash(pin));
  }

  static Future<bool> verifyTransferPin(String pin) async {
    final p = await _prefs();
    final stored = p.getString(_transferPinKey);
    if (stored == null || stored.isEmpty) return true; // no PIN set = free access
    return stored == _hash(pin);
  }

  static Future<void> clearTransferPin() async {
    final p = await _prefs();
    await p.remove(_transferPinKey);
  }
}
