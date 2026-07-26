import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class HandshakeCryptoService {
  static final Random _random = Random.secure();

  /// Generate a 16-byte random cryptographic nonce
  static String generateNonce() {
    final values = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Shared Master Salt for OFFPAY 2-Way Handshake
  static const String _masterSalt = 'OFFPAY_2WAY_MUTUAL_HANDSHAKE_SALT_2026';

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
    final signature = sha256.convert(utf8.encode('$jsonStr:$_masterSalt')).toString().substring(0, 10);

    final payloadBase64 = base64Url.encode(utf8.encode(jsonStr));
    final fullPacket = 'OFFPAY_HS_STEP1:$payloadBase64:$signature';

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
      if (!step1Packet.startsWith('OFFPAY_HS_STEP1:')) return null;

      final parts = step1Packet.split(':');
      if (parts.length < 3) return null;

      final payloadBase64 = parts[1];
      final signature = parts[2];

      final jsonStr = utf8.decode(base64Url.decode(payloadBase64));
      final expectedSig = sha256.convert(utf8.encode('$jsonStr:$_masterSalt')).toString().substring(0, 10);

      // Validate cryptographic signature
      if (signature != expectedSig) return null;

      final senderData = jsonDecode(jsonStr) as Map<String, dynamic>;
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
      final responseSig = sha256.convert(utf8.encode('$responseJson:$_masterSalt')).toString().substring(0, 10);
      final responseBase64 = base64Url.encode(utf8.encode(responseJson));

      final step2Packet = 'OFFPAY_HS_STEP2:$responseBase64:$responseSig';

      return {
        'packet': step2Packet,
        'senderData': senderData,
        'receiverNonce': receiverNonce,
        'signature': responseSig,
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
      if (!step2Packet.startsWith('OFFPAY_HS_STEP2:')) return false;

      final parts = step2Packet.split(':');
      if (parts.length < 3) return false;

      final payloadBase64 = parts[1];
      final signature = parts[2];

      final jsonStr = utf8.decode(base64Url.decode(payloadBase64));
      final expectedSig = sha256.convert(utf8.encode('$jsonStr:$_masterSalt')).toString().substring(0, 10);

      if (signature != expectedSig) return false;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map['sNonce'] == expectedSenderNonce && map['status'] == 'MUTUAL_VERIFIED';
    } catch (_) {
      return false;
    }
  }
}
