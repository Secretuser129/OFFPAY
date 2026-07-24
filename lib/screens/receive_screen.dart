import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/bluetooth_service.dart';
import '../services/profile_service.dart';
import '../services/firebase_service.dart';
import '../models/wallet_model.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  _ReceiveScreenState createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> with SingleTickerProviderStateMixin {
  String deviceId = 'OFFPAY-LOADING';
  String macAddress = 'Loading...';
  String userName = 'OFFPAY User';
  StreamSubscription<Map<String, dynamic>>? _incomingPaymentSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadProfileData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
      bluetoothService.setInPaymentFlow(true);
      _incomingPaymentSubscription = bluetoothService.onIncomingPayment.listen((paymentData) {
        _handleIncomingPayment(paymentData);
      });
    });
  }

  Future<void> _loadProfileData() async {
    final id = await ProfileService.getDeviceId();
    final mac = await ProfileService.getBluetoothMacAddress();
    final name = await ProfileService.getUserName();
    final btName = await ProfileService.getBluetoothName();

    if (mounted) {
      setState(() {
        deviceId = id;
        macAddress = mac;
        userName = name;
      });

      final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
      bluetoothService.startListeningForPayments(deviceId: id, userName: btName);
    }
  }

  @override
  void dispose() {
    _incomingPaymentSubscription?.cancel();
    _pulseController.dispose();
    final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
    bluetoothService.setInPaymentFlow(false);
    bluetoothService.stopListeningForPayments();
    super.dispose();
  }

  Future<void> _handleIncomingPayment(Map<String, dynamic> data) async {
    final double amount = (data['amount'] as num).toDouble();
    final String senderId = data['senderId'] as String;

    HapticFeedback.vibrate();

    final walletModel = Provider.of<WalletModel>(context, listen: false);
    await walletModel.receiveMoney(amount, senderId, status: 'PENDING');

    // Update Server Cloud Ledger automatically in background
    FirebaseService.syncWithFirebase(walletModel).catchError((_) => <String, dynamic>{});

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Payment Received!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text('Received via Offline Bluetooth BLE from:'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                senderId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Money Mode'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pulsing BLE Receiver Radar Circle
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 180 + (_pulseController.value * 24),
                  height: 180 + (_pulseController.value * 24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.1 + (0.1 * (1 - _pulseController.value))),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3 + (0.4 * _pulseController.value)),
                      width: 2 + (2 * _pulseController.value),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.indigo,
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 36),

            Text(
              'BLE Listening Active',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_tethering, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Broadcasting: $userName OFFPAY',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Phone Bluetooth Address & Device ID Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth, size: 16, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text(
                        'Device ID: $deviceId',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Bluetooth Address: $macAddress',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.hintColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Nearby phones will automatically detect your device and send money over Bluetooth BLE.',
              style: TextStyle(fontSize: 13, color: theme.hintColor),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Exit Receive Mode'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}