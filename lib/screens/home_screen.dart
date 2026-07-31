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
import '../services/sync_queue_service.dart';
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
      SyncQueueService.startQueue(walletModel);
      
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
      await walletModel.receiveMoney(amount, senderId, status: 'PENDING', transactionId: txId, notify: false);
      SyncQueueService.enqueueAndTrigger(walletModel);
    });
  }

  @override
  void dispose() {
    SyncQueueService.stopQueue();
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
    await walletModel.receiveMoney(500.00, 'OFFPAY-DEMO');
  }

  @override
  Widget build(BuildContext context) {
    final walletModel = Provider.of<WalletModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OFFPAY',
          style: TextStyle(
            fontFamily: '.SF Pro Display',
            fontFamilyFallback: [
              '-apple-system',
              'BlinkMacSystemFont',
              'SF Pro Text',
              'SF Pro Icons',
              'Helvetica Neue',
              'Helvetica',
              'Arial',
              'sans-serif',
            ],
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.6,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'System Diagnostics & Health',
            onPressed: () {
              Navigator.pushNamed(context, '/diagnostics');
            },
          ),
          IconButton(
            icon: const Icon(Icons.notes_outlined),
            tooltip: 'System & Security Logs',
            onPressed: () {
              Navigator.pushNamed(context, '/logs');
            },
          ),
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
              ValueListenableBuilder<int>(
                valueListenable: SyncQueueService.pendingCountNotifier,
                builder: (context, pendingCount, _) {
                  if (pendingCount == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: SyncQueueService.isSyncingNotifier,
                          builder: (context, isSyncing, _) {
                            return isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                                  )
                                : const Icon(Icons.sync_problem, color: Colors.amber, size: 20);
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$pendingCount offline transaction(s) pending cloud sync.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.amberAccent
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => SyncQueueService.enqueueAndTrigger(walletModel),
                          child: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 300.ms).slideY(begin: -0.1, end: 0);
                },
              ),
              _buildBalanceCard(walletModel).animate().fade(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 20),
              _buildQuickActions(context).animate(delay: 150.ms).fade().slideY(begin: 0.1, end: 0),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isBalanceHidden
              ? (isDark
                  ? [const Color(0xFF2C2C3A), const Color(0xFF1E1E2C)]
                  : [Colors.grey.shade500, Colors.grey.shade700])
              : (isDark
                  ? [const Color(0xFF1E1E30), const Color(0xFF0F172A)]
                  : [Theme.of(context).primaryColor, Theme.of(context).primaryColorDark]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                GestureDetector(
                  onTap: _toggleBalanceVisibility,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(eyeIcon, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Classy Pill button for Judge Demo Mode
                InkWell(
                  onTap: _triggerJudgeDemo,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade300.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Demo +₹500',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Manual reload button
                Tooltip(
                  message: 'Refresh Balance & Sync',
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final walletModel = Provider.of<WalletModel>(context, listen: false);
                      await walletModel.refreshBalance();
                      
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 5),
                          Text(
                            'Sync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionIcon(
              context: context,
              icon: Icons.send_rounded,
              label: 'Send',
              color: Colors.blueAccent,
              onTap: () => Navigator.pushNamed(context, '/send_options'),
            ),
            _buildActionIcon(
              context: context,
              icon: Icons.call_received_rounded,
              label: 'Receive',
              color: Colors.greenAccent,
              onTap: () => Navigator.pushNamed(context, '/receive'),
            ),
            _buildActionIcon(
              context: context,
              icon: Icons.radar_rounded,
              label: 'BLE Radar',
              color: Colors.orangeAccent,
              onTap: () => Navigator.pushNamed(context, '/discovery'),
            ),
            _buildActionIcon(
              context: context,
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan QR',
              color: Colors.purpleAccent,
              onTap: () => Navigator.pushNamed(context, '/qr_scanner'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionIcon({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            _buildStatusBadge(transaction.status, transaction.isCredit),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isCredit) {
    Color bg;
    Color text;
    String label;
    IconData icon;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status.toUpperCase()) {
      case 'RECEIVED':
      case 'VERIFIED':
      case 'SYNCED':
      case 'SUCCESS':
      case 'SENT':
      case 'NFC_SUCCESS':
        bg = Colors.green.withValues(alpha: 0.15);
        text = isDark ? Colors.greenAccent : Colors.green;
        label = (status.toUpperCase() == 'VERIFIED' || status.toUpperCase() == 'SYNCED')
            ? (isCredit ? 'Received (Verified)' : 'Verified')
            : (isCredit ? 'Received' : 'Success');
        icon = Icons.check_circle;
        break;
      case 'PROCESS':
      case 'QUEUED_FOR_RELAY':
      case 'PENDING':
      case 'RETRYING':
        bg = Colors.amber.withValues(alpha: 0.15);
        text = isDark ? Colors.amberAccent : Colors.amber.shade900;
        label = status.toUpperCase() == 'RETRYING'
            ? 'Retrying Sync'
            : (status.toUpperCase() == 'QUEUED_FOR_RELAY'
                ? 'Mesh Queued'
                : (status.toUpperCase() == 'PENDING' ? 'Pending Sync' : 'In Process'));
        icon = Icons.sync;
        break;
      case 'FAILED':
      case 'SYNC_FAILED':
      default:
        bg = Colors.red.withValues(alpha: 0.15);
        text = isDark ? Colors.redAccent : Colors.red;
        label = status.toUpperCase() == 'SYNC_FAILED' ? 'Sync Failed' : 'Failed';
        icon = Icons.cancel;
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
    final isDark = theme.brightness == Brightness.dark;
    final Color secondaryTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.primaryColor.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              Row(
                children: [
                  if (walletModel.history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _showAllTransactions(context, walletModel);
                      },
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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
