import 'package:hive/hive.dart';

part "transaction_model.g.dart";

@HiveType(typeId: 1)
class TransactionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String recipientId;

  @HiveField(4)
  final bool isCredit;

  @HiveField(5)
  final String transactionId;

  @HiveField(6)
  String status; // 'RECEIVED', 'PROCESS', 'FAILED', 'VERIFIED'

  @HiveField(7)
  String? paymentMethod; // 'bluetooth', 'online'

  TransactionModel({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.recipientId,
    required this.isCredit,
    required this.transactionId,
    this.status = 'RECEIVED',
    this.paymentMethod,
  });

  /// Automatically resolve payment method ('bluetooth' vs 'online')
  String get method {
    if (paymentMethod != null && paymentMethod!.isNotEmpty) {
      return paymentMethod!;
    }
    // Automatically infer for legacy/existing transactions
    if (transactionId.startsWith('ONL') || transactionId.startsWith('TXN-ONL') || status == 'SYNCED') {
      return 'online';
    }
    return 'bluetooth';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'recipientId': recipientId,
      'isCredit': isCredit,
      'transactionId': transactionId,
      'status': status,
      'paymentMethod': paymentMethod,
    };
  }

  factory TransactionModel.fromMap(Map<dynamic, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      recipientId: map['recipientId']?.toString() ?? 'Unknown',
      isCredit: map['isCredit'] as bool? ?? false,
      transactionId: map['transactionId']?.toString() ?? 'TXN${map['id']}',
      status: map['status']?.toString() ?? 'RECEIVED',
      paymentMethod: map['paymentMethod']?.toString(),
    );
  }
}