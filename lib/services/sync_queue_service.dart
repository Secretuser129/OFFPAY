// lib/services/sync_queue_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import 'firebase_service.dart';

/// Manages background synchronization queue and exponential retries for offline
/// transactions (PENDING, RETRYING, QUEUED_FOR_RELAY) to ensure eventually-consistent cloud state.
class SyncQueueService {
  static Timer? _queueTimer;
  static bool _isProcessing = false;

  /// Tracks the number of retry attempts per transaction ID to prevent infinite loops.
  static final Map<String, int> _retryAttempts = {};

  /// Maximum allowed automatic retry attempts before marking a transaction as SYNC_FAILED.
  static const int maxRetryAttempts = 12;

  /// Reactive notifier for UI indicators showing how many offline transactions are waiting for sync.
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  /// Reactive notifier indicating if a sync cycle is actively running.
  static final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  /// Start the background sync queue timer (checks every 6 seconds).
  static void startQueue(WalletModel walletModel) {
    stopQueue();
    // Trigger an immediate initial check
    processQueue(walletModel);

    _queueTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      processQueue(walletModel);
    });
  }

  /// Stop the background sync queue timer.
  static void stopQueue() {
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  /// Immediately enqueue and trigger queue processing (e.g. after offline NFC or BLE payment).
  static Future<void> enqueueAndTrigger(WalletModel walletModel) async {
    _updatePendingCount(walletModel);
    return processQueue(walletModel);
  }

  /// Force sync ALL pending transactions in one button press without needing multiple clicks
  static Future<void> forceSyncAll(WalletModel walletModel) async {
    _isProcessing = false; // reset lock
    _retryAttempts.clear(); // reset retry counters
    _updatePendingCount(walletModel);

    for (int i = 0; i < 3; i++) {
      final pending = walletModel.history.where((tx) =>
          tx.status != 'VERIFIED' && tx.status != 'SYNCED').toList();
      if (pending.isEmpty) break;

      await processQueue(walletModel);
      _updatePendingCount(walletModel);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Process all unverified transactions in the wallet history.
  static Future<void> processQueue(WalletModel walletModel) async {
    if (_isProcessing) return;

    final unverified = walletModel.history.where((tx) =>
        tx.status != 'VERIFIED' && tx.status != 'SYNCED').toList();

    pendingCountNotifier.value = unverified.length;
    if (unverified.isEmpty) return;

    _isProcessing = true;
    isSyncingNotifier.value = true;

    try {
      // Check retry limits and mark permanent sync failures for excessively retried items
      for (final tx in unverified) {
        final currentAttempts = _retryAttempts[tx.transactionId] ?? 0;
        if (currentAttempts >= maxRetryAttempts) {
          debugPrint('Transaction ${tx.transactionId} reached max sync retries ($maxRetryAttempts). Marking SYNC_FAILED.');
          await walletModel.updateTransactionStatus(tx.transactionId, 'SYNC_FAILED');
        } else {
          _retryAttempts[tx.transactionId] = currentAttempts + 1;
        }
      }

      // Execute cloud synchronization for remaining unverified items
      final syncResult = await FirebaseService.syncWithFirebase(walletModel);
      final bool success = syncResult['success'] == true;

      if (success) {
        // Clean up retry counts for items that are now verified
        final nowVerified = walletModel.history.where((tx) =>
            tx.status == 'VERIFIED' || tx.status == 'SYNCED');
        for (final tx in nowVerified) {
          _retryAttempts.remove(tx.transactionId);
        }
      }
    } catch (e) {
      debugPrint('SyncQueueService process error: $e');
    } finally {
      _updatePendingCount(walletModel);
      _isProcessing = false;
      isSyncingNotifier.value = false;
    }
  }

  static void _updatePendingCount(WalletModel walletModel) {
    final count = walletModel.history.where((tx) =>
        tx.status != 'VERIFIED' && tx.status != 'SYNCED').length;
    pendingCountNotifier.value = count;
  }

  /// Force reset retry counter for a specific transaction (e.g. user taps "Retry Now" on UI).
  static Future<void> resetAndRetryTransaction(WalletModel walletModel, String transactionId) async {
    _retryAttempts.remove(transactionId);
    await walletModel.updateTransactionStatus(transactionId, 'RETRYING');
    await enqueueAndTrigger(walletModel);
  }
}
