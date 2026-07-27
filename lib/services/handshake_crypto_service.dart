import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class HandshakeCryptoService {
  static final Random _random = Random.secure();
  static const String _masterSalt = 'OFFPAY_2WAY_MUTUAL_HANDSHAKE_SALT_2026';

  /// Generate a 16-byte random cryptographic nonce
  static String generateNonce() {
    final values = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Get the derived 32-byte Key for AES-256
  static enc.Key _getEncryptionKey() {
    final keyBytes = sha256.convert(utf8.encode(_masterSalt)).bytes;
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  /// Step 1: Sender generates Handshake Challenge packet to send to Receiver
  static Map<String, String> createSenderHandshake({
    required String senderDeviceId,
    required String senderName,
    required double amount,
    int seq = 1,
    String prevHash = 'GENESIS_OFFPAY_CHAIN_HASH_00000000',
  }) {
    final nonce = generateNonce();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final rawPayload = {
      'sId': senderDeviceId,
      'sName': senderName,
      'amt': amount,
      'nonce': nonce,
      'seq': seq,
      'prevHash': prevHash,
      'ts': timestamp,
    };

    final jsonStr = jsonEncode(rawPayload);
    
    // 1. Encrypt via AES-256-CBC
    final key = _getEncryptionKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);
    
    // Packet content is "IV_base64:Ciphertext_base64"
    final packetPayload = '${iv.base64}:${encrypted.base64}';
    
    // 2. Sign via HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(_masterSalt));
    final signature = hmac.convert(utf8.encode(packetPayload)).toString();

    final fullPacket = 'OFFPAY_HS_SEC1:$packetPayload:$signature';

    return {
      'packet': fullPacket,
      'nonce': nonce,
      'signature': signature,
    };
  }

  /// Step 2: Receiver validates Step 1 challenge and creates Handshake Response packet
  static Map<String, dynamic>? createReceiverResponse({
    required String step1Packet,
    required String receiverDeviceId,
  }) {
    try {
      if (!step1Packet.startsWith('OFFPAY_HS_SEC1:')) return null;

      final parts = step1Packet.split(':');
      // Format: OFFPAY_HS_SEC1 : IV_base64 : Ciphertext_base64 : Signature_hex
      if (parts.length < 4) return null;

      final ivBase64 = parts[1];
      final ciphertextBase64 = parts[2];
      final signature = parts[3];

      final packetPayload = '$ivBase64:$ciphertextBase64';

      // 1. Verify HMAC-SHA256 signature
      final hmac = Hmac(sha256, utf8.encode(_masterSalt));
      final expectedSig = hmac.convert(utf8.encode(packetPayload)).toString();
      if (signature != expectedSig) return null;

      // 2. Decrypt via AES-256-CBC
      final key = _getEncryptionKey();
      final iv = enc.IV.fromBase64(ivBase64);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decryptedStr = encrypter.decrypt(enc.Encrypted.fromBase64(ciphertextBase64), iv: iv);

      final senderData = jsonDecode(decryptedStr) as Map<String, dynamic>;
      final receiverNonce = generateNonce();
      final responseTimestamp = DateTime.now().millisecondsSinceEpoch;

      final rawResponse = {
        'rId': receiverDeviceId,
        'sId': senderData['sId'],
        'sNonce': senderData['nonce'],
        'rNonce': receiverNonce,
        'ts': responseTimestamp,
        'status': 'MUTUAL_VERIFIED',
      };

      final responseJson = jsonEncode(rawResponse);
      
      // Encrypt response payload
      final respIv = enc.IV.fromSecureRandom(16);
      final respEncrypted = encrypter.encrypt(responseJson, iv: respIv);
      final respPacketPayload = '${respIv.base64}:${respEncrypted.base64}';
      
      // Sign response payload
      final respSignature = hmac.convert(utf8.encode(respPacketPayload)).toString();
      final step2Packet = 'OFFPAY_HS_SEC2:$respPacketPayload:$respSignature';

      return {
        'packet': step2Packet,
        'senderData': senderData,
        'receiverNonce': receiverNonce,
        'signature': respSignature,
      };
    } catch (_) {
      return null;
    }
  }

  /// Step 3: Sender validates Receiver Step 2 response packet to complete mutual handshake
  static bool verifyReceiverResponse({
    required String step2Packet,
    required String expectedSenderNonce,
  }) {
    try {
      if (!step2Packet.startsWith('OFFPAY_HS_SEC2:')) return false;

      final parts = step2Packet.split(':');
      // Format: OFFPAY_HS_SEC2 : IV_base64 : Ciphertext_base64 : Signature_hex
      if (parts.length < 4) return false;

      final ivBase64 = parts[1];
      final ciphertextBase64 = parts[2];
      final signature = parts[3];

      final packetPayload = '$ivBase64:$ciphertextBase64';

      // 1. Verify HMAC-SHA256 signature
      final hmac = Hmac(sha256, utf8.encode(_masterSalt));
      final expectedSig = hmac.convert(utf8.encode(packetPayload)).toString();
      if (signature != expectedSig) return false;

      // 2. Decrypt via AES-256-CBC
      final key = _getEncryptionKey();
      final iv = enc.IV.fromBase64(ivBase64);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decryptedStr = encrypter.decrypt(enc.Encrypted.fromBase64(ciphertextBase64), iv: iv);

      final map = jsonDecode(decryptedStr) as Map<String, dynamic>;
      return map['sNonce'] == expectedSenderNonce && map['status'] == 'MUTUAL_VERIFIED';
    } catch (_) {
      return false;
    }
  }
}
