// lib/services/sequence_chaining_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cryptographic Anti-Double-Spend & Sequence Chaining Service
/// Prevents replay attacks by enforcing monotonically incrementing sequence numbers
/// and SHA-256 hash chaining (similar to an offline ledger chain).
class SequenceChainingService {
  static const String _seqKeyPrefix = 'offpay_seq_';
  static const String _hashKeyPrefix = 'offpay_hash_';
  static const String _nonceKeyPrefix = 'offpay_nonce_';
  static const String _genesisHash = 'GENESIS_OFFPAY_CHAIN_HASH_00000000';

  /// Get and increment the outgoing sequence number for a specific target/sender
  static Future<int> getNextSequence(String counterpartyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_seqKeyPrefix$counterpartyId';
    final currentSeq = prefs.getInt(key) ?? 0;
    final nextSeq = currentSeq + 1;
    await prefs.setInt(key, nextSeq);
    debugPrint('SequenceChainingService: Incremented seq for $counterpartyId to $nextSeq');
    return nextSeq;
  }

  /// Get the last recorded transaction hash in the chain for a device
  static Future<String> getLastHash(String counterpartyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_hashKeyPrefix$counterpartyId';
    return prefs.getString(key) ?? _genesisHash;
  }

  /// Compute the SHA-256 chaining hash for a transaction packet
  static String computeChainHash({
    required String prevHash,
    required String nonce,
    required int seq,
    required double amount,
    required int timestamp,
  }) {
    final dataStr = '$prevHash:$nonce:$seq:$amount:$timestamp';
    final bytes = utf8.encode(dataStr);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Convenience method for verifying diagnostic chains
  static String generateChainedHash({
    required String previousHash,
    required String currentTxId,
    required double amount,
    required int timestamp,
  }) {
    return computeChainHash(
      prevHash: previousHash,
      nonce: currentTxId,
      seq: 1,
      amount: amount,
      timestamp: timestamp,
    );
  }

  /// Verify incoming transaction sequence number, replay nonce, and update local ledger chain.
  /// Returns a record: (isValid: bool, reason: String?)
  static Future<({bool isValid, String? reason})> verifyAndRecordIncomingTransaction({
    required String senderId,
    required int incomingSeq,
    required String nonce,
    required String prevHash,
    required double amount,
    required int timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check if this nonce has EVER been seen before (Anti-Replay / Anti-Double-Spend)
    final nonceKey = '$_nonceKeyPrefix$nonce';
    final isNonceSeen = prefs.getBool(nonceKey) ?? false;
    if (isNonceSeen) {
      debugPrint('REPLAY_ATTACK_DETECTED: Nonce $nonce has already been processed!');
      return (
        isValid: false,
        reason: 'REPLAY_ATTACK_DETECTED: Transaction token has already been spent.',
      );
    }

    // 2. Check monotonically incrementing sequence number
    final seqKey = '$_seqKeyPrefix$senderId';
    final lastSeenSeq = prefs.getInt(seqKey) ?? 0;
    if (incomingSeq <= lastSeenSeq) {
      debugPrint(
        'REPLAY_ATTACK_DETECTED: Incoming seq $incomingSeq <= Last seen seq $lastSeenSeq for $senderId',
      );
      return (
        isValid: false,
        reason: 'SEQUENCE_ERROR: Incoming sequence number ($incomingSeq) must be greater than last seen ($lastSeenSeq). Possible rollback or replay attack.',
      );
    }

    // 3. Compute and record the new chain hash
    final newHash = computeChainHash(
      prevHash: prevHash,
      nonce: nonce,
      seq: incomingSeq,
      amount: amount,
      timestamp: timestamp,
    );

    await prefs.setBool(nonceKey, true);
    await prefs.setInt(seqKey, incomingSeq);
    await prefs.setString('$_hashKeyPrefix$senderId', newHash);

    debugPrint(
      'SequenceChainingService: Validated & chained transaction from $senderId (seq: $incomingSeq, newHash: $newHash)',
    );

    return (isValid: true, reason: null);
  }

  /// Check if a nonce was already seen without mutating state
  static Future<bool> isNonceSpent(String nonce) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_nonceKeyPrefix$nonce') ?? false;
  }
}
