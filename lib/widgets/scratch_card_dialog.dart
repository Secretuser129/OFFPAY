// lib/widgets/scratch_card_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/reward_service.dart';
import '../services/theme_service.dart';

class ScratchCardDialog extends StatefulWidget {
  final RewardCard rewardCard;

  const ScratchCardDialog({
    super.key,
    required this.rewardCard,
  });

  static Future<void> show(
    BuildContext context, {
    required RewardCard rewardCard,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScratchCardDialog(
        rewardCard: rewardCard,
      ),
    );
  }

  @override
  State<ScratchCardDialog> createState() => _ScratchCardDialogState();
}

class _ScratchCardDialogState extends State<ScratchCardDialog>
    with SingleTickerProviderStateMixin {
  final List<Offset> _scratchedPoints = [];
  late bool _isRevealed;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.rewardCard.isClaimed;
  }

  void _onPanUpdate(DragUpdateDetails details, Size cardSize) {
    if (_isRevealed) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = details.localPosition;
    if (localPosition.dx >= 0 &&
        localPosition.dx <= cardSize.width &&
        localPosition.dy >= 0 &&
        localPosition.dy <= cardSize.height) {
      setState(() {
        _scratchedPoints.add(localPosition);
      });

      if (_scratchedPoints.length % 4 == 0) {
        HapticFeedback.selectionClick();
      }

      if (_scratchedPoints.length > 35 && !_isRevealed) {
        _revealCard();
      }
    }
  }

  void _revealCard() {
    setState(() {
      _isRevealed = true;
    });
    HapticFeedback.heavyImpact();
  }

  Future<void> _claimReward() async {
    if (_isClaiming || widget.rewardCard.isClaimed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isClaiming = true;
    });

    await RewardService.claimCard(context, widget.rewardCard);

    if (!mounted) return;
    final curr = ThemeProvider.currentCurrency;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.rewardCard.rewardType == 'CASHBACK'
              ? '🎉 Claimed $curr${widget.rewardCard.rewardValue} Cashback into your wallet!'
              : widget.rewardCard.rewardType == 'CASHBACK_COUPON'
                  ? '🎉 Claimed ${curr}25 Cashback + AMZN-OFFPAY Coupon Code included!'
                  : widget.rewardCard.rewardType == 'AMAZON_COUPON'
                      ? '🎉 Amazon Coupon Code ready to copy: ${widget.rewardCard.rewardValue}'
                      : '🎉 Unlocked Collectible Role: ${widget.rewardCard.rewardValue}!',
        ),
        backgroundColor: Colors.amber.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Keep dialog open if coupon code is present so user can copy/read it!
    if (widget.rewardCard.rewardType == 'CASHBACK_COUPON' || widget.rewardCard.rewardType == 'AMAZON_COUPON') {
      setState(() {
        _isClaiming = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _copyCouponCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Coupon Code "$code" copied to clipboard!')),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const cardSize = Size(280, 180);

    final card = widget.rewardCard;

    IconData icon;
    String mainTitle;
    String subTitle;

    if (card.rewardType == 'CASHBACK') {
      icon = Icons.account_balance_wallet;
      mainTitle = '₹${card.rewardValue} Cashback';
      subTitle = 'Added directly to your offline wallet';
    } else if (card.rewardType == 'CASHBACK_COUPON') {
      icon = Icons.card_giftcard;
      mainTitle = '₹${card.rewardValue} + Amazon Coupon';
      subTitle = '₹25 Cashback added to wallet & Coupon code included!';
    } else if (card.rewardType == 'AMAZON_COUPON') {
      icon = Icons.local_offer;
      mainTitle = card.rewardValue;
      subTitle = 'Amazon Special Coupon Reward!';
    } else {
      icon = Icons.military_tech;
      mainTitle = card.rewardValue;
      subTitle = card.roleAbility ?? 'Special achievement unlocked!';
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 10,
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉 ', style: TextStyle(fontSize: 24)),
                Text(
                  card.isClaimed ? 'Reward Claimed' : 'Reward!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                  ),
                ),
                const Text(' 🎁', style: TextStyle(fontSize: 24)),
              ],
            ).animate().scale().fade(),

            const SizedBox(height: 8),

            Text(
              card.isClaimed
                  ? 'You have already collected this reward for Transaction #${card.transactionId}.'
                  : _isRevealed
                      ? 'Congratulations! Claim your reward below:'
                      : 'Scratch the foil card with your finger to reveal!',
              style: TextStyle(
                fontSize: 13,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Scratch Card Area
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: cardSize.width,
                height: cardSize.height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Underneath Reward Layer
                    Container(
                      width: cardSize.width,
                      height: cardSize.height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade700,
                            Colors.amber.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 44, color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            mainTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subTitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (card.rewardType == 'CASHBACK_COUPON' || card.rewardType == 'AMAZON_COUPON') ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_offer, color: Colors.amberAccent, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    card.rewardType == 'CASHBACK_COUPON' ? 'AMZN-OFFPAY-50OFF' : card.rewardValue,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Metallic Foil Scratch Layer (Hidden when revealed or already claimed)
                    if (!_isRevealed)
                      GestureDetector(
                        onPanUpdate: (details) =>
                            _onPanUpdate(details, cardSize),
                        child: CustomPaint(
                          size: cardSize,
                          painter: _FoilScratchPainter(
                            points: _scratchedPoints,
                          ),
                        ),
                      ),

                    if (_isRevealed)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ).animate().shimmer(duration: 1200.ms),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if ((_isRevealed || card.isClaimed) &&
                (card.rewardType == 'CASHBACK_COUPON' || card.rewardType == 'AMAZON_COUPON')) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final code = card.rewardType == 'CASHBACK_COUPON' ? 'AMZN-OFFPAY-50OFF' : card.rewardValue;
                    _copyCouponCode(code);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text('Copy Coupon Code', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.amberAccent : Colors.amber.shade900,
                    side: BorderSide(color: isDark ? Colors.amberAccent : Colors.amber.shade700, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (card.isClaimed)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Already Claimed • Close'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else if (_isRevealed)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _claimReward,
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    card.rewardType == 'CASHBACK'
                        ? 'Claim ${ThemeProvider.currentCurrency}${card.rewardValue} Cashback'
                        : card.rewardType == 'CASHBACK_COUPON'
                            ? 'Claim ${ThemeProvider.currentCurrency}${card.rewardValue} + Amazon Coupon'
                            : card.rewardType == 'AMAZON_COUPON'
                                ? 'Claim Amazon Coupon Code'
                                : 'Claim Collectible Role',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ).animate().fade().scale()
            else
              TextButton(
                onPressed: _revealCard,
                child: const Text(
                  'Instant Reveal ->',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoilScratchPainter extends CustomPainter {
  final List<Offset> points;

  _FoilScratchPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final foilPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.grey.shade400,
          Colors.grey.shade600,
          Colors.grey.shade400,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, foilPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '💎 SCRATCH & WIN 💎',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 38.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FoilScratchPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
