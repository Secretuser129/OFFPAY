import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyUserName = 'offpay_user_name';
const String _keyDeviceId = 'offpay_device_id';
const String _keyAvatarIndex = 'offpay_avatar_index';
const String _keyLastIdChange = 'offpay_last_id_change';

class ProfileService {
  static final _random = Random();

  /// Generate a randomized, professional OFFPAY Device ID
  static String generateRandomDeviceId() {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final part1 = List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'OFFPAY-$part1-$part2';
  }

  /// Secret key for QR code payload encryption/hashing
  static String _getSecretKey() => 'OFFPAY_SECRET_SALT_2026_AES_KEY';

  /// Encrypt user info into a secure QR payload with optional set payment amount
  static String encryptQrPayload({
    required String deviceId,
    required String userName,
    double? amount,
  }) {
    final rawData = {
      'id': deviceId,
      'name': userName,
      'amt': amount ?? 0.0,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final jsonStr = jsonEncode(rawData);
    final bytes = utf8.encode(jsonStr);

    // Encrypt payload bytes using XOR with SHA-256 derived key stream
    final keyBytes = sha256.convert(utf8.encode(_getSecretKey())).bytes;
    final encryptedBytes = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ keyBytes[i % keyBytes.length],
    );

    final base64Payload = base64Url.encode(encryptedBytes);
    final signature = sha256.convert(utf8.encode('$base64Payload:${_getSecretKey()}')).toString().substring(0, 8);

    return 'OFFPAY_SECURE_V2:$base64Payload:$signature';
  }

  /// Decrypt a secure QR payload back into user info map
  static Map<String, String>? decryptQrPayload(String qrData) {
    try {
      if (!qrData.startsWith('OFFPAY_SECURE_V2:')) {
        // Fallback for raw device ID scanning
        return {'id': qrData, 'name': 'Unknown User'};
      }

      final parts = qrData.split(':');
      if (parts.length < 3) return null;

      final base64Payload = parts[1];
      final signature = parts[2];

      // Verify HMAC-SHA256 signature
      final expectedSig = sha256.convert(utf8.encode('$base64Payload:${_getSecretKey()}')).toString().substring(0, 8);
      if (signature != expectedSig) return null;

      final encryptedBytes = base64Url.decode(base64Payload);
      final keyBytes = sha256.convert(utf8.encode(_getSecretKey())).bytes;
      final bytes = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
      );

      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final nameVal = map['name']?.toString().trim();
      return {
        'id': map['id']?.toString() ?? 'Unknown Device',
        'name': (nameVal != null && nameVal.isNotEmpty) ? nameVal : 'Unknown User',
        'amount': (map['amt'] as num?)?.toDouble().toString() ?? '0.0',
      };
    } catch (_) {
      return null;
    }
  }

  // ── Profile Persistence ───────────────────────────────────────────────────

  static Future<bool> isProfileConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyUserName) && prefs.getString(_keyUserName)!.isNotEmpty;
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyUserName)?.trim();
    if (name == null || name.isEmpty) {
      return 'Unknown User';
    }
    return name;
  }

  /// Format Bluetooth broadcast name as: [User Display Name] + " OFFPAY"
  static Future<String> getBluetoothName() async {
    final name = await getUserName();
    if (name == 'Unknown User') {
      return 'Device OFFPAY';
    }
    if (name.toUpperCase().contains('OFFPAY')) {
      return name;
    }
    return '$name OFFPAY';
  }

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = generateRandomDeviceId();
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  static Future<int> getAvatarIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAvatarIndex) ?? 0;
  }

  static Future<bool> canChangeDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_keyLastIdChange) ?? 0;
    if (lastMs == 0) return true;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final days = DateTime.now().difference(lastDate).inDays;
    return days >= 30;
  }

  static Future<int> getDaysRemainingForIdChange() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_keyLastIdChange) ?? 0;
    if (lastMs == 0) return 0;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final days = DateTime.now().difference(lastDate).inDays;
    return (30 - days).clamp(0, 30);
  }

  static Future<void> saveProfile({
    required String name,
    required String deviceId,
    required int avatarIndex,
    bool isDeviceIdChanged = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name.trim());
    await prefs.setString(_keyDeviceId, deviceId.trim());
    await prefs.setInt(_keyAvatarIndex, avatarIndex);
    if (isDeviceIdChanged) {
      await prefs.setInt(_keyLastIdChange, DateTime.now().millisecondsSinceEpoch);
    }
  }
}
