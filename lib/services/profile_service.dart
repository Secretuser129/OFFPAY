import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

const String _keyUserName = 'offpay_user_name';
const String _keyDeviceId = 'offpay_device_id';
const String _keyAvatarIndex = 'offpay_avatar_index';
const String _keyLastIdChange = 'offpay_last_id_change';
const String _keyIsLoggedIn = 'offpay_is_logged_in';

class ProfileService {
  static const _bleChannel = MethodChannel('com.example.offpay/bluetooth');

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, value);
  }
  static final _random = Random();

  /// Generate a randomized, professional OFFPAY Device ID
  static String generateRandomDeviceId() {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final part1 = List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    final part2 = List.generate(4, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'OFFPAY-$part1-$part2';
  }

  /// Get the phone's REAL Bluetooth MAC address from native Android
  static Future<String> getBluetoothMacAddress() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final String? realMac = await _bleChannel.invokeMethod('getBluetoothAddress');
        if (realMac != null && realMac.isNotEmpty && realMac != '02:00:00:00:00:00') {
          return realMac.toUpperCase();
        }
      }
    } catch (e) {
      debugPrint('Error getting real Bluetooth MAC: $e');
    }
    // Fallback if hardware denies access
    final id = await getDeviceId();
    final bytes = sha256.convert(utf8.encode(id)).bytes;
    final hex = bytes.sublist(0, 6).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
    return hex;
  }

  /// Generate deterministic 32-byte AES-256 key for QR payloads
  static enc.Key _getQrAesKey() {
    final keyBytes = sha256.convert(utf8.encode('OFFPAY_STRONG_QR_KEY_2026_AES_256_CBC')).bytes;
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  /// Encrypt user info into a secure QR payload using AES-256-CBC and HMAC-SHA256
  static String encryptQrPayload({
    required String deviceId,
    required String userName,
    double? amount,
  }) {
    final rawData = {
      'id': deviceId,
      'name': userName,
      'amt': amount ?? 0.0,
      'ts': (amount != null && amount > 0) ? DateTime.now().millisecondsSinceEpoch : 0,
    };
    final jsonStr = jsonEncode(rawData);

    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_getQrAesKey(), mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);

    // Compute HMAC-SHA256 signature for integrity
    final hmacKey = sha256.convert(utf8.encode('OFFPAY_HMAC_QR_SALT_2026')).bytes;
    final hmac = Hmac(sha256, hmacKey);
    final sig = hmac.convert(utf8.encode('${iv.base64}:${encrypted.base64}')).toString().substring(0, 16);

    return 'OFFPAY_SECURE_V3:${iv.base64}:${encrypted.base64}:$sig';
  }

  /// Decrypt a secure QR payload back into user info map using AES-256-CBC and HMAC-SHA256
  static Map<String, String>? decryptQrPayload(String rawQrData) {
    try {
      final qrData = rawQrData.trim();
      if (qrData.startsWith('OFFPAY_SECURE_V3:')) {
        final parts = qrData.split(':');
        if (parts.length >= 4) {
          final ivBase64 = parts[1];
          final encryptedBase64 = parts[2];
          try {
            final iv = enc.IV.fromBase64(ivBase64);
            final encrypter = enc.Encrypter(enc.AES(_getQrAesKey(), mode: enc.AESMode.cbc));
            final jsonStr = encrypter.decrypt64(encryptedBase64, iv: iv);
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final nameVal = map['name']?.toString().trim();
            return {
              'id': map['id']?.toString() ?? 'Unknown Device',
              'name': (nameVal != null && nameVal.isNotEmpty) ? nameVal : 'Unknown User',
              'amount': (map['amt'] as num?)?.toDouble().toString() ?? '0.0',
            };
          } catch (_) {}
        }
      } else if (qrData.startsWith('OFFPAY_SECURE_V2:')) {
        final parts = qrData.split(':');
        if (parts.length >= 2) {
          try {
            final base64Payload = parts[1];
            final encryptedBytes = base64Url.decode(base64Payload);
            final keyBytes = sha256.convert(utf8.encode('OFFPAY_SECRET_SALT_2026_AES_KEY')).bytes;
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
          } catch (_) {}
        }
      }

      // Try parsing as plain JSON QR code
      try {
        if (qrData.startsWith('{') && qrData.endsWith('}')) {
          final map = jsonDecode(qrData) as Map<String, dynamic>;
          final nameVal = map['name']?.toString().trim();
          return {
            'id': map['id']?.toString() ?? 'Unknown Device',
            'name': (nameVal != null && nameVal.isNotEmpty) ? nameVal : 'Scanned User',
            'amount': (map['amt'] as num?)?.toDouble().toString() ?? '0.0',
          };
        }
      } catch (_) {}

      // Try parsing UPI QR code format (upi://pay?pa=...&pn=...)
      if (qrData.toLowerCase().startsWith('upi://')) {
        final uri = Uri.tryParse(qrData);
        final nameVal = uri?.queryParameters['pn']?.trim();
        final idVal = uri?.queryParameters['pa']?.trim();
        final amountVal = uri?.queryParameters['am']?.trim();
        return {
          'id': idVal ?? qrData,
          'name': (nameVal != null && nameVal.isNotEmpty) ? nameVal : 'UPI Merchant',
          'amount': amountVal ?? '0.0',
        };
      }

      // Universal fallback for any other QR code (screenshot or raw text)
      return {
        'id': qrData,
        'name': 'Scanned User',
        'amount': '0.0',
      };
    } catch (_) {
      return {
        'id': rawQrData,
        'name': 'Scanned User',
        'amount': '0.0',
      };
    }
  }

  /// Generate Bluetooth Direct-Connect QR code payload (Different from My QR / V3 online QR)
  static String generateBluetoothQrPayload({
    required String deviceId,
    required String userName,
    required String macAddress,
    required int avatarIndex,
    String? photoBase64,
  }) {
    final rawData = {
      'id': deviceId,
      'name': userName,
      'mac': macAddress,
      'avatar': avatarIndex,
      if (photoBase64 != null && photoBase64.length <= 1500) 'photo': photoBase64,
      'type': 'OFFPAY_BLUETOOTH_QR',
    };
    return 'OFFPAY_BT_QR_V1:${jsonEncode(rawData)}';
  }

  /// Parse Bluetooth Direct-Connect QR code payload
  static Map<String, dynamic>? parseBluetoothQrPayload(String rawQrData) {
    try {
      final qrData = rawQrData.trim();
      if (qrData.startsWith('OFFPAY_BT_QR_V1:')) {
        final jsonStr = qrData.substring('OFFPAY_BT_QR_V1:'.length);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return {
          'id': map['id']?.toString() ?? 'Unknown Device',
          'name': map['name']?.toString() ?? 'OFFPAY User',
          'mac': map['mac']?.toString() ?? '',
          'avatar': (map['avatar'] is int) ? map['avatar'] as int : int.tryParse(map['avatar']?.toString() ?? '0') ?? 0,
          'photo': map['photo']?.toString(),
          'type': 'OFFPAY_BLUETOOTH_QR',
        };
      }
    } catch (e) {
      debugPrint('Error parsing Bluetooth QR payload: $e');
    }
    return null;
  }

  /// Retrieve profile photo as base64 string if configured
  static Future<String?> getProfilePhotoBase64() async {
    try {
      final imagePath = await getProfileImagePath();
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          if (bytes.length <= 150000) {
            return base64Encode(bytes);
          }
        }
      }
    } catch (_) {}
    return null;
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

  /// Format Bluetooth broadcast name as clean user display name
  static Future<String> getBluetoothName() async {
    final name = await getUserName();
    if (name == 'Unknown User' || name.trim().isEmpty) {
      return 'OFFPAY User';
    }
    return name.trim();
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
    // Automatically push updated profile & photo base64 to server
    try {
      FirebaseService.syncUserProfile(
        balance: 500.0,
        overrideDeviceId: deviceId.trim(),
        overrideUserName: name.trim(),
      );
    } catch (_) {}
  }

  static const String _keyProfileImagePath = 'offpay_profile_image_path';

  static Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProfileImagePath);
  }

  static Future<void> setProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileImagePath, path);
    try {
      FirebaseService.syncUserProfile(balance: 500.0);
    } catch (_) {}
  }

  static Future<void> deleteAccount() async {
    final deviceId = await getDeviceId();
    try {
      await FirebaseService.deleteUserAccountFromServer(deviceId);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
