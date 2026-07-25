import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Handles the storing, broadcasting, and receiving of Offline Mesh Relay Packets.
class MeshRelayService {
  static const String _relayBoxKey = 'relay_packets';
  static bool _isInitialized = false;

  /// Initialize the Hive box for relay packets
  static Future<void> init() async {
    if (!_isInitialized) {
      await Hive.openBox(_relayBoxKey);
      _isInitialized = true;
    }
  }

  /// Queues a failed or out-of-range transaction packet into the Mesh Relay
  static Future<void> queueRelayPacket(String transactionId, String encryptedPayload) async {
    if (!_isInitialized) await init();
    final box = Hive.box(_relayBoxKey);
    
    // Store the payload mapped by transaction ID
    await box.put(transactionId, encryptedPayload);
    debugPrint('MeshRelayService: Queued transaction $transactionId for offline relay.');
    
    // Begin broadcasting that we have a relay packet
    _startRelayBeacon();
  }

  /// Retrieves all pending relay packets
  static Future<Map<String, String>> getPendingRelays() async {
    if (!_isInitialized) await init();
    final box = Hive.box(_relayBoxKey);
    final relays = <String, String>{};
    
    for (final key in box.keys) {
      relays[key.toString()] = box.get(key) as String;
    }
    return relays;
  }

  /// Removes a relay packet once it has been successfully delivered or synced
  static Future<void> clearRelayPacket(String transactionId) async {
    if (!_isInitialized) await init();
    final box = Hive.box(_relayBoxKey);
    await box.delete(transactionId);
    debugPrint('MeshRelayService: Cleared transaction $transactionId from relay queue.');
  }

  /// Broadcasts a lightweight BLE beacon indicating this device is carrying relay packets
  static void _startRelayBeacon() {
    // In a full implementation, this would use the native Android Advertiser to broadcast
    // a specific UUID (e.g., OFFPAY_RELAY_UUID) so other nearby devices know this node 
    // has packets to forward.
    debugPrint('MeshRelayService: Broadcasting Mesh Relay Beacon...');
  }
}
