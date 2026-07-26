// lib/widgets/scratch_card_dialog.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';

class ScratchCardDialog extends StatefulWidget {
  final double paymentAmount;
  final String recipientName;

  const ScratchCardDialog({
    super.key,
    required this.paymentAmount,
    required this.recipientName,
  });

  static Future<void> show(
    BuildContext context, {
    required double paymentAmount,
    required String recipientName,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScratchCardDialog(
        paymentAmount: paymentAmount,
        recipientName: recipientName,
      ),
    );
  }

  @override
  State<ScratchCardDialog> createState() => _ScratchCardDialogState();
}

class _ScratchCardDialogState extends State<ScratchCardDialog>
    with SingleTickerProviderStateMixin {
  final List<Offset> _scratchedPoints = [];
  bool _isRevealed = false;
  bool _rewardClaimed = false;

  late final bool _isCashback;
  late final int _cashbackAmount;
  late final String _badgeTitle;

  @override
  void initState() {
    super.initState();
    final random = Random();
    // 70% chance of cashback, 30% chance of badge unlock
    _isCashback = random.nextDouble() < 0.70;
    _cashbackAmount = random.nextInt(46) + 5; // Between ₹5 and ₹50

    final badges = [
      '⚡ Offline Pioneer Badge',
      '🛡️ Zero-Net Defender',
      '🚀 Bluetooth Voyager',
      '💎 Sovereign Offline User',
    ];
    _badgeTitle = badges[random.nextInt(badges.length)];
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

      // Haptic feedback while scratching
      if (_scratchedPoints.length % 4 == 0) {
        HapticFeedback.selectionClick();
      }

      // Check if enough area is scratched (~35 points)
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
    if (_rewardClaimed) return;
    setState(() {
      _rewardClaimed = true;
    });

    if (_isCashback) {
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      await walletModel.addMoney(
        _cashbackAmount.toDouble(),
        'OFFPAY Cashback Reward',
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const cardSize = Size(280, 180);

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
            // Celebratory Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉 ', style: TextStyle(fontSize: 24)),
                Text(
                  'Scratch Card Reward!',
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
              _isRevealed
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
                          Icon(
                            _isCashback
                                ? Icons.card_giftcard
                                : Icons.military_tech,
                            size: 44,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isCashback
                                ? '₹$_cashbackAmount CASHBACK'
                                : _badgeTitle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCashback
                                ? 'Added directly to your offline wallet'
                                : 'Special Achievement Unlocked!',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Metallic Foil Scratch Layer (Hidden when revealed)
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

                    // Confetti and celebratory shine when revealed
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
            if (_isRevealed)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _claimReward,
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    _isCashback
                        ? 'Claim ₹$_cashbackAmount Cashback'
                        : 'Claim Special Badge',
                    style: const TextStyle(
                      fontSize: 16,
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

/// Painter that renders the metallic foil cover and cuts out scratched areas
class _FoilScratchPainter extends CustomPainter {
  final List<Offset> points;

  _FoilScratchPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // Save layer to apply eraser clipping
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw Metallic Foil Cover
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

    // Draw Decorative pattern on foil
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

    // 2. Erase Scratched Points
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
