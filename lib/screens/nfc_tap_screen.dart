// lib/screens/nfc_tap_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../services/nfc_service.dart';
import '../services/sync_queue_service.dart';
import 'payment_success_screen.dart';

class NfcTapScreen extends StatefulWidget {
  final double? initialAmount;
  final String? recipientName;

  const NfcTapScreen({
    super.key,
    this.initialAmount,
    this.recipientName,
  });

  @override
  State<NfcTapScreen> createState() => _NfcTapScreenState();
}

class _NfcTapScreenState extends State<NfcTapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController =
      TextEditingController(text: 'NFC Merchant Store');
  bool _isTransferring = false;
  String _statusText = 'Hold phones back-to-back to pay';
  bool _isReceiveMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(0);
    } else {
      _amountController.text = '50';
    }
    if (widget.recipientName != null && widget.recipientName!.isNotEmpty) {
      _recipientController.text = widget.recipientName!;
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _triggerNfcTap() async {
    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isTransferring = true;
      _statusText = 'NFC Contact detected! Transmitting encrypted payload...';
    });

    HapticFeedback.mediumImpact();

    if (_isReceiveMode) {
      // Receive mode simulation
      final success = await NfcService.simulateReceiveNfcPayment(
        amount: amount,
        senderName: 'NFC Payer (${DateTime.now().second}s)',
      );

      if (!mounted) return;
      if (success) {
        final walletModel = Provider.of<WalletModel>(context, listen: false);
        await walletModel.receiveMoney(amount, 'NFC Payer', status: 'PENDING');
        SyncQueueService.enqueueAndTrigger(walletModel);
        HapticFeedback.heavyImpact();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              amount: amount,
              recipientName: 'Received via NFC Tap',
            ),
          ),
        );
      }
    } else {
      // Send mode simulation
      final txId = await NfcService.executeNfcTapTransfer(
        amount: amount,
        recipientName: _recipientController.text,
        recipientDeviceId: 'NFC_DEVICE_TARGET_01',
      );

      if (!mounted) return;
      if (txId != null) {
        final walletModel = Provider.of<WalletModel>(context, listen: false);
        await walletModel.sendMoney(
          amount,
          'NFC_DEVICE_TARGET_01',
          status: 'NFC_SUCCESS',
          transactionId: txId,
        );

        HapticFeedback.heavyImpact();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              amount: amount,
              recipientName: _recipientController.text,
            ),
          ),
        );
      } else {
        setState(() {
          _isTransferring = false;
          _statusText = 'NFC Transfer failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Tap-to-Pay'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isReceiveMode ? Icons.call_received : Icons.send),
            tooltip: 'Switch Mode',
            onPressed: () {
              setState(() {
                _isReceiveMode = !_isReceiveMode;
                _statusText = _isReceiveMode
                    ? 'Hold phone back-to-back to receive'
                    : 'Hold phones back-to-back to pay';
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Speed & Offline Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.cyan.withValues(alpha: 0.15)
                      : Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyan.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.cyan, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _isReceiveMode
                          ? 'RECEIVE MODE • NFC INSTANT'
                          : 'SEND MODE • <100ms OFFLINE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.cyanAccent : Colors.cyan.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ).animate().fade().scale(),

              const SizedBox(height: 32),

              // Animated Pulsing NFC Ring
              SizedBox(
                height: 240,
                width: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Wave 1
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final val = _pulseController.value;
                        return Container(
                          width: 80 + (160 * val),
                          height: 80 + (160 * val),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.cyan.withValues(alpha: 1.0 - val),
                              width: 2.5,
                            ),
                          ),
                        );
                      },
                    ),
                    // Concentric Wave 2
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final val = (_pulseController.value + 0.5) % 1.0;
                        return Container(
                          width: 80 + (160 * val),
                          height: 80 + (160 * val),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 1.0 - val),
                              width: 2.0,
                            ),
                          ),
                        );
                      },
                    ),
                    // Center NFC Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.primaryColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.contactless_outlined,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // Amount and Recipient Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      if (!_isReceiveMode) ...[
                        TextField(
                          controller: _recipientController,
                          decoration: const InputDecoration(
                            labelText: 'Recipient Store / Name',
                            prefixIcon: Icon(Icons.storefront),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: _isReceiveMode
                              ? 'Amount to Request (₹)'
                              : 'Amount to Pay (₹)',
                          prefixText: '₹ ',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 200.ms).fade().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 28),

              // Action Button (Simulate Tap-to-Pay / Tap-to-Receive)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isTransferring ? null : _triggerNfcTap,
                  icon: _isTransferring
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.touch_app, size: 24),
                  label: Text(
                    _isTransferring
                        ? 'Transmitting (<100ms)...'
                        : (_isReceiveMode
                            ? 'Simulate NFC Tap to Receive'
                            : 'Simulate NFC Tap to Pay'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ).animate(delay: 300.ms).fade().scale(),

              const SizedBox(height: 16),

              Text(
                'Uses sequence chaining & NDEF formatting for 100% offline contactless security.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
