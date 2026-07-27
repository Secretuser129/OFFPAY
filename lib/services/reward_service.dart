// lib/services/reward_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet_model.dart';

class CollectibleRole {
  final String id;
  final String title;
  final String icon;
  final String ability;
  final DateTime unlockedAt;

  CollectibleRole({
    required this.id,
    required this.title,
    required this.icon,
    required this.ability,
    required this.unlockedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'icon': icon,
        'ability': ability,
        'unlockedAt': unlockedAt.toIso8601String(),
      };

  factory CollectibleRole.fromMap(Map<String, dynamic> map) => CollectibleRole(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        icon: map['icon'] ?? '💎',
        ability: map['ability'] ?? '',
        unlockedAt: DateTime.tryParse(map['unlockedAt'] ?? '') ?? DateTime.now(),
      );
}

class RewardCard {
  final String id;
  final String transactionId;
  final double transactionAmount;
  final DateTime createdAt;
  final DateTime expiryDate;
  bool isClaimed;
  final String rewardType; // 'CASHBACK', 'AMAZON_COUPON', 'ROLE_BADGE'
  final String rewardValue; // e.g. '25', 'AMZN-OFFPAY-50OFF', '⚡ Offline Pioneer'
  final String? roleAbility;

  RewardCard({
    required this.id,
    required this.transactionId,
    required this.transactionAmount,
    required this.createdAt,
    required this.expiryDate,
    this.isClaimed = false,
    required this.rewardType,
    required this.rewardValue,
    this.roleAbility,
  });

  bool get isExpired => !isClaimed && DateTime.now().isAfter(expiryDate);

  int get daysRemaining {
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'transactionId': transactionId,
        'transactionAmount': transactionAmount,
        'createdAt': createdAt.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'isClaimed': isClaimed,
        'rewardType': rewardType,
        'rewardValue': rewardValue,
        'roleAbility': roleAbility,
      };

  factory RewardCard.fromMap(Map<String, dynamic> map) => RewardCard(
        id: map['id'] ?? '',
        transactionId: map['transactionId'] ?? '',
        transactionAmount: (map['transactionAmount'] ?? 0.0).toDouble(),
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        expiryDate: DateTime.tryParse(map['expiryDate'] ?? '') ??
            DateTime.now().add(const Duration(days: 10)),
        isClaimed: map['isClaimed'] ?? false,
        rewardType: map['rewardType'] ?? 'CASHBACK',
        rewardValue: map['rewardValue'] ?? '10',
        roleAbility: map['roleAbility'],
      );
}

class RewardService {
  static const String _rewardsKey = 'offpay_rewards_list';
  static const String _rolesKey = 'offpay_unlocked_roles_list';

  static List<RewardCard> _cards = [];
  static List<CollectibleRole> _unlockedRoles = [];

  static final List<CollectibleRole> allAvailableRoles = [
    CollectibleRole(
      id: 'pioneer',
      title: '⚡ Offline Pioneer',
      icon: '⚡',
      ability: '+5% bonus on next offline cashback reward',
      unlockedAt: DateTime.now(),
    ),
    CollectibleRole(
      id: 'defender',
      title: '🛡️ Zero-Net Defender',
      icon: '🛡️',
      ability: 'Priority BLE routing & zero relay delay',
      unlockedAt: DateTime.now(),
    ),
    CollectibleRole(
      id: 'sovereign',
      title: '💎 Sovereign Offline User',
      icon: '💎',
      ability: 'VIP Gold badge & unlocked higher BLE limits',
      unlockedAt: DateTime.now(),
    ),
    CollectibleRole(
      id: 'voyager',
      title: '🚀 Bluetooth Voyager',
      icon: '🚀',
      ability: 'Extended discovery scan range & instant handshake',
      unlockedAt: DateTime.now(),
    ),
  ];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final cardsJson = prefs.getStringList(_rewardsKey) ?? [];
    _cards = cardsJson
        .map((str) => RewardCard.fromMap(jsonDecode(str)))
        .toList();

    final rolesJson = prefs.getStringList(_rolesKey) ?? [];
    _unlockedRoles = rolesJson
        .map((str) => CollectibleRole.fromMap(jsonDecode(str)))
        .toList();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final cardsJson = _cards.map((c) => jsonEncode(c.toMap())).toList();
    await prefs.setStringList(_rewardsKey, cardsJson);

    final rolesJson =
        _unlockedRoles.map((r) => jsonEncode(r.toMap())).toList();
    await prefs.setStringList(_rolesKey, rolesJson);
  }

  /// Only transactions >= 1000 qualify for scratch cards
  static bool isEligibleForScratchCard(double amount) {
    return amount >= 1000.0;
  }

  /// Prevents opening multiple scratch cards for the same transactionId
  static bool hasCardForTransaction(String transactionId) {
    return _cards.any((card) => card.transactionId == transactionId);
  }

  static RewardCard? getCardForTransaction(String transactionId) {
    try {
      return _cards.firstWhere((card) => card.transactionId == transactionId);
    } catch (_) {
      return null;
    }
  }

  /// Generates a tiered reward based on transaction amount
  static Future<RewardCard?> generateRewardForTransaction({
    required String transactionId,
    required double amount,
  }) async {
    if (!isEligibleForScratchCard(amount)) return null;
    if (hasCardForTransaction(transactionId)) {
      return getCardForTransaction(transactionId);
    }

    final random = Random();
    String rewardType = 'CASHBACK';
    String rewardValue = '10';
    String? roleAbility;

    if (amount >= 30000.0) {
      // 30000+ amount get 2% percent cashback of payment amount and 75% Zero-Net Defender chance to get rewarded from scratch
      final isRole = random.nextDouble() < 0.75;
      if (isRole) {
        final role = allAvailableRoles.firstWhere(
          (r) => r.id == 'defender',
          orElse: () => allAvailableRoles[1],
        );
        rewardType = 'ROLE_BADGE';
        rewardValue = role.title;
        roleAbility = role.ability;
      } else {
        rewardType = 'CASHBACK';
        final cashback = (amount * 0.02).round();
        rewardValue = cashback.toString();
      }
    } else if (amount >= 10000.0) {
      // 10000-25000 = 25 ruppee cashbacks + coupon include , 25% Zero-Net Defender chance to get rewarded from scratch card
      final isRole = random.nextDouble() < 0.25;
      if (isRole) {
        final role = allAvailableRoles.firstWhere(
          (r) => r.id == 'defender',
          orElse: () => allAvailableRoles[1],
        );
        rewardType = 'ROLE_BADGE';
        rewardValue = role.title;
        roleAbility = role.ability;
      } else {
        rewardType = 'CASHBACK_COUPON';
        rewardValue = '25';
      }
    } else if (amount >= 5000.0) {
      // 5000-9999 = 10-16 ruppe cashbacks
      rewardType = 'CASHBACK';
      rewardValue = (random.nextInt(7) + 10).toString(); // 10 to 16
    } else {
      // 1000-4999 (including 1000-1999) = 5-10 ruppe cashbacks
      rewardType = 'CASHBACK';
      rewardValue = (random.nextInt(6) + 5).toString(); // 5 to 10
    }

    final newCard = RewardCard(
      id: 'RW_${DateTime.now().millisecondsSinceEpoch}',
      transactionId: transactionId,
      transactionAmount: amount,
      createdAt: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 10)),
      isClaimed: false,
      rewardType: rewardType,
      rewardValue: rewardValue,
      roleAbility: roleAbility,
    );

    _cards.insert(0, newCard);
    await _save();
    return newCard;
  }

  /// Claim a reward card and credit to offline wallet with status 'RECEIVED'
  static Future<void> claimCard(BuildContext context, RewardCard card) async {
    if (card.isClaimed || card.isExpired) return;

    card.isClaimed = true;

    if (card.rewardType == 'CASHBACK' || card.rewardType == 'CASHBACK_COUPON') {
      final cashbackAmount = double.tryParse(card.rewardValue) ?? 10.0;
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      // Included in payment history with standard 'RECEIVED' status
      await walletModel.receiveMoney(
        cashbackAmount,
        'OFFPAY Cashback Reward',
        status: 'RECEIVED',
      );
    } else if (card.rewardType == 'ROLE_BADGE') {
      final exists = _unlockedRoles.any((r) => r.title == card.rewardValue);
      if (!exists) {
        final roleObj = allAvailableRoles.firstWhere(
          (r) => r.title == card.rewardValue,
          orElse: () => CollectibleRole(
            id: 'custom',
            title: card.rewardValue,
            icon: '💎',
            ability: card.roleAbility ?? 'Special offline VIP privileges',
            unlockedAt: DateTime.now(),
          ),
        );
        _unlockedRoles.insert(0, roleObj);
      }
    }

    await _save();
  }

  static List<RewardCard> getUnclaimedCards() {
    return _cards.where((c) => !c.isClaimed && !c.isExpired).toList();
  }

  static List<RewardCard> getClaimedCards() {
    return _cards.where((c) => c.isClaimed).toList();
  }

  static List<CollectibleRole> getUnlockedRoles() {
    return List.unmodifiable(_unlockedRoles);
  }

  static List<CollectibleRole> getAllAvailableRoles() {
    return List.unmodifiable(allAvailableRoles);
  }
}
