import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/bluetooth_service.dart';
import '../services/password_service.dart';

import '../services/firebase_service.dart';
import '../services/update_service.dart';
import '../widgets/global_apple_dock.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBalanceHidden = false;
  Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      if (!walletModel.isInitialized) {
        await walletModel.init();
      }
      
      // Auto-sync offline transactions silently on load (no popup for normal users)
      FirebaseService.syncWithFirebase(walletModel).catchError((_) => <String, dynamic>{});
      FirebaseService.startAutoSync(walletModel);
      
      UpdateService.checkForUpdates(context, silent: true);
    });

    // Auto-reload balance every 3 seconds for responsive updates without stuttering
    _autoReloadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      walletModel.refreshBalance();
    });

    // Listen for side-by-side BLE device proximity pop-up trigger
    final btService = Provider.of<OffpayBluetoothService>(context, listen: false);
    btService.onProximityDeviceDetected.listen((device) {
      _showSideBySideProximityPopup(device);
    });

    // Listen for incoming BLE payments while on HomeScreen
    btService.onIncomingPayment.listen((data) async {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final double amount = (data['amount'] as num).toDouble();
      final String senderId = data['senderId'] as String;
      final String? txId = data['transactionId'] as String?;
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      await walletModel.receiveMoney(amount, senderId, status: 'VERIFIED', transactionId: txId);
      FirebaseService.syncWithFirebase(walletModel).catchError((_) => <String, dynamic>{});
    });
  }

  @override
  void dispose() {
    FirebaseService.stopAutoSync();
    _autoReloadTimer?.cancel();
    super.dispose();
  }

  void _showSideBySideProximityPopup(DiscoveredDevice device) {
    if (!mounted) return;
    // Only show popup when user is on HomeScreen
    if (ModalRoute.of(context)?.isCurrent != true) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_connected, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('OFFPAY Device Nearby!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Side-by-side Bluetooth connection detected:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${device.id}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Signal: ${device.rssi} dBm (${device.estimatedDistance})',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Connect & Pay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(
                context,
                '/payment_input',
                arguments: device.device,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBalanceVisibility() async {
    // If hiding balance, toggle immediately
    if (!_isBalanceHidden) {
      setState(() => _isBalanceHidden = true);
      return;
    }

    // If unhiding balance, check if balance PIN is set
    final hasPin = await PasswordService.hasBalancePin();
    if (!hasPin) {
      setState(() => _isBalanceHidden = false);
      return;
    }

    // Prompt for PIN before showing balance
    if (!mounted) return;
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Enter Balance PIN'),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '4-6 digit PIN',
              prefixIcon: Icon(Icons.key),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter PIN';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final isValid = await PasswordService.verifyBalancePin(pinController.text.trim());
                if (isValid) {
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() => _isBalanceHidden = false);
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Incorrect PIN! Access denied.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }


  void _triggerJudgeDemo() async {
    final walletModel = Provider.of<WalletModel>(context, listen: false);
    // Directly add ₹500.00 to balance for instant update without snackbar
    await walletModel.receiveMoney(500.00, 'STAGE-JUDGE-DEMO');
  }

  @override
  Widget build(BuildContext context) {
    final walletModel = Provider.of<WalletModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.light ? Colors.white : Theme.of(context).cardTheme.color,
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
              ),
            ),
            const SizedBox(width: 12),
            const Text('OFF-PAY'),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Security Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/security_settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildBalanceCard(walletModel).animate().fade(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 24),
              _buildTransactionHistory(walletModel),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/home'),
    );
  }

  Widget _buildBalanceCard(WalletModel walletModel) {
    final String balanceText = _isBalanceHidden ? '****.**' : '₹${walletModel.balance.toStringAsFixed(2)}';
    final IconData eyeIcon = _isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isBalanceHidden
              ? [Colors.grey.shade600, Colors.grey.shade800]
              : [Theme.of(context).primaryColor, Theme.of(context).primaryColorDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                GestureDetector(
                  onTap: _toggleBalanceVisibility,
                  child: Icon(eyeIcon, color: Colors.white, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                balanceText,
                key: ValueKey<bool>(_isBalanceHidden),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Plus button in left side corner of balance for Judge Demo Mode
                InkWell(
                  onTap: _triggerJudgeDemo,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Judge Demo',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Manual reload button (Icon-only with increased size)
                Tooltip(
                  message: 'Refresh Balance',
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final walletModel = Provider.of<WalletModel>(context, listen: false);
                      await walletModel.refreshBalance();
                      
                      // Also pull down online transfers from Firebase Server
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Syncing with Server...'), duration: Duration(seconds: 1)),
                      );
                      bool synced = await FirebaseService.syncDownFromServer(walletModel);
                      if (synced && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Balance and History Synced!'), backgroundColor: Colors.green),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel transaction) {
    final isCredit = transaction.isCredit;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedTime = DateFormat('MMM d, yyyy • HH:mm').format(transaction.timestamp);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: transaction),
            ),
          );
        },
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCredit
                ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade100)
                : (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade100),
            border: isDark ? Border.all(color: isCredit ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.4)) : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? (isDark ? Colors.greenAccent : Colors.green) : (isDark ? Colors.redAccent : Colors.red),
          ),
        ),
        title: Text(
          isCredit ? 'Received' : 'Sent',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Device ID: ${transaction.recipientId}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              formattedTime,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '−'}₹${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isCredit ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusBadge(transaction.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;
    IconData icon;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status.toUpperCase()) {
      case 'QUEUED_FOR_RELAY':
        bg = Colors.blue.withValues(alpha: 0.15);
        text = isDark ? Colors.blueAccent : Colors.blue.shade900;
        label = 'Pending Sync';
        icon = Icons.sync;
        break;
      case 'PENDING':
        bg = Colors.amber.withValues(alpha: 0.15);
        text = isDark ? Colors.amberAccent : Colors.amber.shade900;
        label = 'Pending';
        icon = Icons.hourglass_top;
        break;
      case 'FAILED':
        bg = Colors.red.withValues(alpha: 0.15);
        text = isDark ? Colors.redAccent : Colors.red;
        label = 'Failed';
        icon = Icons.cancel;
        break;
      case 'VERIFIED':
      default:
        bg = Colors.green.withValues(alpha: 0.15);
        text = isDark ? Colors.greenAccent : Colors.green;
        label = 'Verified';
        icon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(WalletModel walletModel) {
    final theme = Theme.of(context);
    final Color secondaryTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                if (walletModel.history.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _showAllTransactions(context, walletModel);
                    },
                    child: const Text('View All'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (walletModel.history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions in past 30 days',
                    style: TextStyle(color: secondaryTextColor, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: walletModel.history.length > 5 ? 5 : walletModel.history.length,
            itemBuilder: (context, index) {
              final transaction = walletModel.history[index];
              return _buildTransactionTile(transaction).animate(delay: (100 * index).ms).fade().slideX(begin: 0.1, end: 0);
            },
          ),
        ],
      ),
    );
  }

  void _showAllTransactions(BuildContext context, WalletModel walletModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Transaction History (Stored 30 Days)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: walletModel.history.length,
                    itemBuilder: (context, index) {
                      final transaction = walletModel.history[index];
                      return _buildTransactionTile(transaction).animate(delay: (100 * index).ms).fade().slideX(begin: 0.1, end: 0);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
