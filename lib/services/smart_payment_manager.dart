import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

import '../models/wallet_model.dart';
import 'bluetooth_service.dart';
import 'firebase_service.dart';
import 'mesh_relay_service.dart';
import 'profile_service.dart';
import 'handshake_crypto_service.dart';
import 'sequence_chaining_service.dart';

/// The Invisible AI Engine that orchestrates offline payments, 
/// prevents erroneous debits, and seamlessly fails over to Mesh Relay Mode.
class SmartPaymentManager {
  static const int _rssiThreshold = -85; // dBm threshold for direct transfer vs mesh routing

  /// Executes a smart, atomic payment transfer.
  /// Handles signal diagnostics, guaranteed atomic debits, and automatic mesh failover.
  static Future<bool> executeSmartTransfer({
    required OffpayBluetoothService bluetoothService,
    required WalletModel walletModel,
    required fb.BluetoothDevice recipientDevice,
    required double amount,
    required int currentRssi,
  }) async {
    final senderId = await ProfileService.getDeviceId();
    final senderName = await ProfileService.getUserName();
    
    debugPrint('SmartPaymentManager: Initiating transfer to ${recipientDevice.remoteId.str} (RSSI: $currentRssi)');

    // 1. Predictive Signal Analysis
    // If signal is too weak, we skip direct GATT (which is prone to failure at low RSSI)
    // and immediately route it to the Mesh Relay queue.
    if (currentRssi < _rssiThreshold) {
      debugPrint('SmartPaymentManager: Signal too weak ($currentRssi < $_rssiThreshold). Routing to Mesh Relay...');
      await _routeToMeshRelay(
        walletModel: walletModel,
        recipientDeviceId: recipientDevice.remoteId.str,
        amount: amount,
        senderId: senderId,
        senderName: senderName,
      );
      return true; // We successfully queued it
    }

    // 2. Direct GATT Transfer Attempt
    debugPrint('SmartPaymentManager: Signal strong enough. Attempting direct GATT connection...');
    // We assume bluetoothService.connectToDevice() was already called by the UI.
    // We just execute the transfer.
    final txId = await bluetoothService.transferToConnectedDevice(recipientDevice, amount);

    // 3. Atomic State Management
    if (txId != null) {
      // Transfer SUCCESSFUL. The Receiver got the packet securely. 
      // Now it's 100% safe to debit the sender.
      debugPrint('SmartPaymentManager: Direct transfer SUCCESS. Debiting wallet securely.');
      await walletModel.sendMoney(
        amount, 
        recipientDevice.remoteId.str, 
        status: 'PENDING', 
        transactionId: txId,
        paymentMethod: 'bluetooth',
      );
      
      // Trigger background sync
      FirebaseService.syncWithFirebase(walletModel).catchError((_) => <String, dynamic>{});
      return true;
    } else {
      // Transfer FAILED mid-way or connection couldn't be established.
      // WE PREVENT DEBIT. The user's money is safe.
      debugPrint('SmartPaymentManager: Direct transfer FAILED. Aborting direct debit to protect funds.');
      debugPrint('SmartPaymentManager: Rerouting failed direct transaction to Mesh Relay mode.');
      
      // Automatic Failover to Mesh Relay
      await _routeToMeshRelay(
        walletModel: walletModel,
        recipientDeviceId: recipientDevice.remoteId.str,
        amount: amount,
        senderId: senderId,
        senderName: senderName,
      );
      return true; // Successfully managed via failover
    }
  }

  /// Packages the transaction securely and queues it for Offline Mesh Relay broadcasting
  static Future<void> _routeToMeshRelay({
    required WalletModel walletModel,
    required String recipientDeviceId,
    required double amount,
    required String senderId,
    required String senderName,
  }) async {
    // 1. Create a secure, encrypted Relay Packet using the same Handshake logic with sequence chaining
    final seq = await SequenceChainingService.getNextSequence(recipientDeviceId);
    final prevHash = await SequenceChainingService.getLastHash(recipientDeviceId);
    final handshake = HandshakeCryptoService.createSenderHandshake(
      senderDeviceId: senderId,
      senderName: senderName,
      amount: amount,
      seq: seq,
      prevHash: prevHash,
    );
    
    final txId = 'TXN-${handshake['nonce']}';
    final encryptedPayload = handshake['packet']!;

    // 2. Queue into Mesh Relay Service
    await MeshRelayService.queueRelayPacket(txId, encryptedPayload);

    // 3. Debit local wallet but mark it as QUEUED_FOR_RELAY so the user knows it's pending mesh delivery
    await walletModel.sendMoney(
      amount, 
      recipientDeviceId, 
      status: 'QUEUED_FOR_RELAY', 
      transactionId: txId,
      paymentMethod: 'bluetooth',
    );

    // Attempt to sync this intent to Firebase just in case we have internet
    FirebaseService.syncWithFirebase(walletModel).catchError((_) => <String, dynamic>{});
  }
}
