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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Rewards & Scratch Cards',
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUnclaimedTab(unclaimed, isDark),
            _buildClaimedTab(claimed, isDark),
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
              'No Unclaimed Scratch Cards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Make offline payments of ₹1,000 or more to earn scratch cards with cashback, Amazon coupons, and special badges!',
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];

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
        ).animate(delay: Duration(milliseconds: 50 * index)).fade();
      },
    );
  }
}
