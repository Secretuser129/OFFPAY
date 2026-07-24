// lib/screens/payment_success_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final double amount;
  final String recipientName;

  const PaymentSuccessScreen({
    super.key, 
    required this.amount, 
    required this.recipientName,
  });

  @override
  _PaymentSuccessScreenState createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> with TickerProviderStateMixin {
  late AnimationController _checkAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _checkAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Variables to hold stable transaction data
  late String transactionId;
  late String timestamp;

  @override
  void initState() {
    super.initState();
    
    // Generate static data once
    transactionId = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    timestamp = DateFormat('MMM d, yyyy • HH:mm').format(DateTime.now());

    // Check mark animation
    _checkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkAnimationController, curve: Curves.elasticOut),
    );

    // Slide animation for content
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOut),
    );

    // Fade animation for buttons
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeIn),
    );

    // Start animations in sequence
    _checkAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _slideAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _fadeAnimationController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OffpayBluetoothService>(context, listen: false).setInPaymentFlow(true);
      }
    });
  }

  @override
  void dispose() {
    _checkAnimationController.dispose();
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme data for Dark/Light mode adaptation
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Animated Success Icon with confetti effect
                  ScaleTransition(
                    scale: _checkAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing background circles
                        AnimatedBuilder(
                          animation: _checkAnimationController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green.withValues(alpha: 0.1 * (1 - _checkAnimationController.value)),
                              ),
                              padding: EdgeInsets.all(80 * (1 + _checkAnimationController.value * 0.3)),
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green[50],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 80.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // Animated Success Message
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _slideAnimationController.drive(Tween(begin: 0.0, end: 1.0)),
                      child: Column(
                        children: [
                          Text(
                            'Payment Successful!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.greenAccent : Colors.green[800],
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          Text(
                            'Your offline payment has been completed.',
                            style: TextStyle(fontSize: 16, color: theme.hintColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Animated Transaction Details Card
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _slideAnimationController.drive(Tween(begin: 0.0, end: 1.0)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Use widget.amount and widget.recipientName here
                            _buildAnimatedDetailRow('Amount', '₹${widget.amount.toStringAsFixed(2)}', Colors.green, theme),
                            const Divider(height: 20),
                            _buildAnimatedDetailRow('Recipient', widget.recipientName, Colors.blue, theme),
                            const Divider(height: 20),
                            _buildAnimatedDetailRow('Date & Time', timestamp, theme.textTheme.bodyMedium?.color, theme),
                            const Divider(height: 20),
                            _buildAnimatedDetailRow('Transaction ID', transactionId, theme.textTheme.bodyMedium?.color, theme),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Animated Buttons
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Return Button with hover effect
                        ElevatedButton.icon(
                          icon: const Icon(Icons.home),
                          label: const Text('Return to Dashboard', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Provider.of<OffpayBluetoothService>(context, listen: false).setInPaymentFlow(false);
                            // Navigate and remove all previous routes
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
                          },
                        ),

                        const SizedBox(height: 12),

                        // Share Receipt Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Share Receipt'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            side: BorderSide(color: theme.primaryColor),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share functionality coming soon!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDetailRow(String label, String value, Color? valueColor, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(-20 * (1 - animValue), 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w500, color: theme.hintColor),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: valueColor ?? theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}