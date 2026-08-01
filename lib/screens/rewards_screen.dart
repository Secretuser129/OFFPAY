// lib/screens/rewards_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/reward_service.dart';
import '../widgets/scratch_card_dialog.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final unclaimed = RewardService.getUnclaimedCards();
    final claimed = RewardService.getClaimedCards();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Rewards',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.amber.shade700,
            labelColor: isDark ? Colors.amberAccent : Colors.amber.shade800,
            unselectedLabelColor: theme.hintColor,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.card_giftcard, size: 18),
                    const SizedBox(width: 8),
                    Text('Unclaimed (${unclaimed.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text('Claimed (${claimed.length})'),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Roles & Badges'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUnclaimedTab(unclaimed, isDark),
            _buildClaimedTab(claimed, isDark),
            _buildRolesTab(isDark, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildUnclaimedTab(List<RewardCard> cards, bool isDark) {
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard_outlined,
              size: 72,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Unclaimed Rewards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Make offline payments of ₹1,000 or more to earn cashback, Amazon coupons, and special badges!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final daysLeft = card.daysRemaining;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '🎁',
                      style: TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Reward Card',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Earned from ₹${card.transactionAmount.toStringAsFixed(0)} offline payment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: daysLeft <= 2
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          daysLeft == 0
                              ? 'Expires today!'
                              : 'Expires in $daysLeft days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: daysLeft <= 2
                                ? Colors.red.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ScratchCardDialog.show(context, rewardCard: card);
                    _refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Scratch ->',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: 70 * index)).fade().slideX();
      },
    );
  }

  Widget _buildClaimedTab(List<RewardCard> cards, bool isDark) {
    if (cards.isEmpty) {
      return const Center(
        child: Text(
          'No Claimed Rewards Yet',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    final cashbackCards = cards.where((c) => c.rewardType == 'CASHBACK').toList();
    final couponCards = cards.where((c) => c.rewardType == 'AMAZON_COUPON' || c.rewardType == 'CASHBACK_COUPON').toList();
    final badgeCards = cards.where((c) => c.rewardType == 'ROLE_BADGE').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cashbackCards.isNotEmpty) ...[
          const Text('💰 Cashback Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...cashbackCards.map((c) => _buildClaimedCard(c)),
          const SizedBox(height: 16),
        ],
        if (couponCards.isNotEmpty) ...[
          const Text('🏷️ Coupon Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...couponCards.map((c) => _buildClaimedCard(c)),
          const SizedBox(height: 16),
        ],
        if (badgeCards.isNotEmpty) ...[
          const Text('🎖️ Role Badges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...badgeCards.map((c) => _buildClaimedCard(c)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildClaimedCard(RewardCard card) {
    IconData icon;
    Color iconColor;
    String titleText;
    String subText;

    if (card.rewardType == 'CASHBACK') {
      icon = Icons.account_balance_wallet;
      iconColor = Colors.green;
      titleText = '₹${card.rewardValue} Cashback';
      subText = 'Credited to Offline Wallet';
    } else if (card.rewardType == 'CASHBACK_COUPON') {
      icon = Icons.card_giftcard;
      iconColor = Colors.teal;
      titleText = '₹${card.rewardValue} + Amazon Coupon';
      subText = '₹25 Credited & Coupon Code Included';
    } else if (card.rewardType == 'AMAZON_COUPON') {
      icon = Icons.local_offer;
      iconColor = Colors.orange;
      titleText = card.rewardValue;
      subText = 'Amazon Coupon Code Reward';
    } else {
      icon = Icons.military_tech;
      iconColor = Colors.purple;
      titleText = card.rewardValue;
      subText = card.roleAbility ?? 'Special Role Badge Unlocked';
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subText,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          DateFormat('MMM d').format(card.createdAt),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildRolesTab(bool isDark, ThemeData theme) {
    final unlockedRoles = RewardService.getUnlockedRoles();
    final allRoles = RewardService.getAllAvailableRoles();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: allRoles.map((role) {
        final isUnlocked = unlockedRoles.any((r) => r.id == role.id) || role.id == 'pioneer'; 

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked
                ? (isDark ? Colors.indigo.withValues(alpha: 0.25) : Colors.indigo.withValues(alpha: 0.08))
                : (isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? Colors.indigo.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Text(
                role.icon,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isUnlocked
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.ability,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked ? theme.hintColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                )
              else
                const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
            ],
          ),
        );
      }).toList(),
    );
  }
}
