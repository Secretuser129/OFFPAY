import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'transaction_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

const String _walletBoxName = 'walletBox';
const String _balanceKey = 'currentBalance';
const String _historyKey = 'history_v2';

class WalletModel extends ChangeNotifier {
  late Box _walletBox;
  double _balance = 0.0;
  List<TransactionModel> _history = [];
  bool _isInitialized = false;

  double get balance => _balance;
  List<TransactionModel> get history => List.unmodifiable(_history);
  bool get isInitialized => _isInitialized;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_isInitialized) return;

    _walletBox = await Hive.openBox(_walletBoxName);

    _balance = (_walletBox.get(_balanceKey, defaultValue: 500.00) as num).toDouble();

    // Load stored history with dual-format compatibility (HiveObject or Map)
    final rawList = _walletBox.get(_historyKey, defaultValue: <dynamic>[]) as List;
    final loadedHistory = <TransactionModel>[];

    for (final item in rawList) {
      if (item is TransactionModel) {
        loadedHistory.add(item);
      } else if (item is Map) {
        try {
          loadedHistory.add(TransactionModel.fromMap(item));
        } catch (_) {}
      }
    }

    _history = loadedHistory;

    // Purge transactions older than 30 days
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _history.removeWhere((tx) => tx.timestamp.isBefore(cutoff));

    // Sort newest first
    _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _isInitialized = true;
    notifyListeners();
  }

  // ── Auto-reload / Sync (Optimized for 60 FPS smooth UI) ─────────────────
  Future<void> refreshBalance() async {
    if (!_isInitialized) return;
    final newBalance = (_walletBox.get(_balanceKey, defaultValue: _balance) as num).toDouble();
    final rawList = _walletBox.get(_historyKey, defaultValue: <dynamic>[]) as List;

    // Short-circuit if nothing changed to prevent unnecessary 60 FPS UI rebuilds
    if (newBalance == _balance && rawList.length == _history.length) {
      return;
    }

    _balance = newBalance;
    final loadedHistory = <TransactionModel>[];

    for (final item in rawList) {
      if (item is TransactionModel) {
        loadedHistory.add(item);
      } else if (item is Map) {
        try {
          loadedHistory.add(TransactionModel.fromMap(item));
        } catch (_) {}
      }
    }

    _history = loadedHistory;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _history.removeWhere((tx) => tx.timestamp.isBefore(cutoff));
    _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    notifyListeners();
  }

  // ── Send (debit) ──────────────────────────────────────────────────────────
  Future<bool> sendMoney(double amount, String recipientId, {String status = 'SUCCESS', String? transactionId}) async {
    if (_balance < amount) return false;

    _balance -= amount;

    final now = DateTime.now();
    final newTx = TransactionModel(
      id: now.millisecondsSinceEpoch.toString(),
      amount: amount,
      timestamp: now,
      recipientId: recipientId,
      isCredit: false,
      transactionId: transactionId ?? 'TXN${now.millisecondsSinceEpoch}',
      status: status,
    );

    _history.insert(0, newTx);
    await _saveChanges();
    FirebaseService.syncUserProfile(balance: _balance);
    notifyListeners();
    return true;
  }

  // ── Receive (credit) ──────────────────────────────────────────────────────
  Future<void> receiveMoney(double amount, String senderId, {String status = 'RECEIVED', String? transactionId, bool notify = true, String? senderName}) async {
    _balance += amount;

    final now = DateTime.now();
    final newTx = TransactionModel(
      id: now.millisecondsSinceEpoch.toString(),
      amount: amount,
      timestamp: now,
      recipientId: senderId,
      isCredit: true,
      transactionId: transactionId ?? 'TXN${now.millisecondsSinceEpoch}',
      status: status,
    );

    _history.insert(0, newTx);
    await _saveChanges();
    FirebaseService.syncUserProfile(balance: _balance);
    notifyListeners();

    if (notify && senderId != 'OFFPAY Rewards') {
      await NotificationService.showPaymentReceivedNotification(
        amount: amount,
        senderName: senderName ?? senderId,
        transactionId: newTx.transactionId,
      );
    }
  }

  // ── Status Update (Server Ledger Proof Sync) ──────────────────────────────
  Future<void> updateTransactionStatus(String transactionId, String newStatus) async {
    final index = _history.indexWhere((tx) => tx.transactionId == transactionId || tx.id == transactionId);
    if (index != -1) {
      final old = _history[index];
      _history[index] = TransactionModel(
        id: old.id,
        amount: old.amount,
        timestamp: old.timestamp,
        recipientId: old.recipientId,
        isCredit: old.isCredit,
        transactionId: old.transactionId,
        status: newStatus,
      );
      await _saveChanges();
      notifyListeners();
    }
  }

  // ── Sync from Server (Online transfers) ────────────────────────────────────
  Future<void> mergeFromServer(double serverBalance, List<TransactionModel> serverHistory) async {
    final Set<String> existingTxIds = _history.map((t) => t.transactionId).toSet();
    bool hasNewTx = false;
    double addedCredits = 0.0;
    for (final stx in serverHistory) {
      if (!existingTxIds.contains(stx.transactionId)) {
        _history.add(stx);
        hasNewTx = true;
        if (stx.isCredit) {
          addedCredits += stx.amount;
        } else {
          addedCredits -= stx.amount;
        }
      }
    }
    // When nothing changed in balance or history, short-circuit to prevent unnecessary disk writes and UI rebuilds
    if (!hasNewTx && serverBalance == _balance) {
      return;
    }

    // When a new transaction is received, adjust our local balance by the net added credits/debits
    if (hasNewTx) {
      _balance += addedCredits;
      if (_balance < 0) _balance = 0.0;
      // Sync the newly credited balance back to Firebase server so both local & server match!
      FirebaseService.syncUserProfile(balance: _balance);
    } else if (serverBalance > _balance) {
      // No new transactions, but server balance is higher (e.g. admin update / bonus)
      _balance = serverBalance;
    } else if (_balance > serverBalance) {
      // Ensure server reflects our higher local balance
      FirebaseService.syncUserProfile(balance: _balance);
    }
    if (hasNewTx) {
      _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    await _saveChanges();
    notifyListeners();
  }

  // ── Restore & Logout ───────────────────────────────────────────────────────
  Future<void> restoreData(double newBalance, List<TransactionModel> newHistory) async {
    _balance = newBalance;
    _history = newHistory;
    
    // Sort newest first
    _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    await _saveChanges();
    notifyListeners();
  }

  Future<void> clearWallet() async {
    _balance = 0.0;
    _history = [];
    await _walletBox.put(_balanceKey, _balance);
    await _walletBox.put(_historyKey, []);
    notifyListeners();
  }

  // ── Persist ───────────────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    await _walletBox.put(_balanceKey, _balance);
    final mapList = _history.map((tx) => tx.toMap()).toList();
    await _walletBox.put(_historyKey, mapList);
  }
}