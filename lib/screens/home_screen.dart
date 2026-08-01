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
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../widgets/global_apple_dock.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBalanceHidden = false;
  int _activeBadgeIndex = 1;
  Timer? _autoReloadTimer;

  final Map<String, int> _actionUsageCount = {
    'Receive': 5,
    'BLE Radar': 4,
    'Recharges': 2,
    'Hotel / Resort': 1,
    'Flight Ticket': 1,
    'EMI Payment': 0,
    'Digital Loan': 0,
    'Electrical Bill': 0,
    'Credit Card': 0,
    'Water Bill': 0,
    'Broadband': 0,
  };

  void _recordUsage(String actionKey) {
    HapticFeedback.lightImpact();
    setState(() {
      _actionUsageCount[actionKey] = (_actionUsageCount[actionKey] ?? 0) + 1;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.init();
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

    // Fast background sync every 1500ms from server without loader
    _autoReloadTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      walletModel.refreshBalance();
    });

    // Listen for incoming BLE payments across the entire app
    final btService = Provider.of<OffpayBluetoothService>(context, listen: false);
    btService.onIncomingPayment.listen((data) async {
      final double amount = (data['amount'] as num).toDouble();
      final String senderId = data['senderId'] as String;
      final String? txId = data['transactionId'] as String?;
      final walletModel = Provider.of<WalletModel>(context, listen: false);
      await walletModel.receiveMoney(amount, senderId, status: 'PENDING', transactionId: txId, notify: true);
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

  Widget _buildHeaderStatusBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Node 0: Online
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _activeBadgeIndex = 0);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeBadgeIndex == 0
                    ? (isDark ? Colors.greenAccent : Colors.green)
                    : Colors.transparent,
                border: Border.all(
                  color: isDark ? Colors.greenAccent : Colors.green,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.wifi_rounded,
                size: 11,
                color: _activeBadgeIndex == 0
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.greenAccent : Colors.green),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Center(
              child: Text(
                '•••',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          // Node 1: Auto
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _activeBadgeIndex = 1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeBadgeIndex == 1
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                border: Border.all(
                  color: isDark ? Colors.white : Colors.black,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _activeBadgeIndex == 1
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Center(
              child: Text(
                '•••',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          // Node 2: Offline
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _activeBadgeIndex = 2);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeBadgeIndex == 2
                    ? Colors.grey.shade500
                    : Colors.transparent,
                border: Border.all(
                  color: Colors.grey.shade500,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 11,
                color: _activeBadgeIndex == 2
                    ? Colors.white
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
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
          _buildHeaderStatusBadge(context),
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 24),
            tooltip: 'Settings & Security',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const SizedBox(width: 6),
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
              _buildUtilityServicesGrid(context).animate(delay: 200.ms).fade().slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              _buildTransactionHistory(walletModel),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/home'),
    );
  }

  void _showPaymentOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Quick Payment Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                    child: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                  ),
                  title: const Text('Send Money', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('BLE Radar, Contacts or Direct Send'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/send_options');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purpleAccent.withValues(alpha: 0.15),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.purpleAccent),
                  ),
                  title: const Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Pay any merchant or user QR instantly'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/qr_scanner');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    child: const Icon(Icons.call_received_rounded, color: Colors.green),
                  ),
                  title: const Text('Receive Money', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Show your secure QR or BLE receiver'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/receive');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orangeAccent.withValues(alpha: 0.15),
                    child: const Icon(Icons.tap_and_play_rounded, color: Colors.orangeAccent),
                  ),
                  title: const Text('NFC Tap & Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Contactless offline payment via NFC'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/nfc_tap');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(WalletModel walletModel) {
    final String balanceText = _isBalanceHidden ? '****.**' : '${ThemeProvider.currentCurrency}${walletModel.balance.toStringAsFixed(2)}';
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showPaymentOptionsBottomSheet(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Demo +${ThemeProvider.currentCurrency}500',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Live server sync badge (auto-sync every 1500ms)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Live Sync',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
    // Sort remaining items by usage descending
    final sortedRemaining = _actionUsageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top2 = sortedRemaining.take(2).map((e) => e.key).toList();

    Widget buildDynamicSlot(String actionKey) {
      switch (actionKey) {
        case 'Receive':
          return _buildActionIcon(
            context: context,
            icon: Icons.call_received_rounded,
            label: 'Receive',
            color: Colors.greenAccent,
            onTap: () {
              _recordUsage('Receive');
              Navigator.pushNamed(context, '/receive');
            },
          );
        case 'BLE Radar':
          return _buildActionIcon(
            context: context,
            icon: Icons.radar_rounded,
            label: 'BLE Radar',
            color: Colors.orangeAccent,
            onTap: () {
              _recordUsage('BLE Radar');
              Navigator.pushNamed(context, '/discovery');
            },
          );
        case 'Recharges':
          return _buildActionIcon(
            context: context,
            icon: Icons.phone_android_rounded,
            label: 'Recharges',
            color: Colors.cyan,
            onTap: () {
              _recordUsage('Recharges');
              _showServiceModal(context, 'Recharges', Icons.phone_android_rounded, Colors.cyan);
            },
          );
        case 'Hotel / Resort':
          return _buildActionIcon(
            context: context,
            icon: Icons.hotel_rounded,
            label: 'Hotel/Resort',
            color: Colors.amber,
            onTap: () {
              _recordUsage('Hotel / Resort');
              _showServiceModal(context, 'Hotel / Resort', Icons.hotel_rounded, Colors.amber);
            },
          );
        case 'Flight Ticket':
          return _buildActionIcon(
            context: context,
            icon: Icons.flight_takeoff_rounded,
            label: 'Flights',
            color: Colors.blueAccent,
            onTap: () {
              _recordUsage('Flight Ticket');
              _showServiceModal(context, 'Flight Ticket', Icons.flight_takeoff_rounded, Colors.blueAccent);
            },
          );
        case 'EMI Payment':
          return _buildActionIcon(
            context: context,
            icon: Icons.credit_score_rounded,
            label: 'EMI',
            color: Colors.purpleAccent,
            onTap: () {
              _recordUsage('EMI Payment');
              _showServiceModal(context, 'EMI Payment', Icons.credit_score_rounded, Colors.purpleAccent);
            },
          );
        case 'Digital Loan':
          return _buildActionIcon(
            context: context,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Loans',
            color: Colors.greenAccent,
            onTap: () {
              _recordUsage('Digital Loan');
              _showServiceModal(context, 'Digital Loan', Icons.account_balance_wallet_rounded, Colors.greenAccent);
            },
          );
        case 'Credit Card':
          return _buildActionIcon(
            context: context,
            icon: Icons.credit_card_rounded,
            label: 'Card Bill',
            color: Colors.pinkAccent,
            onTap: () {
              _recordUsage('Credit Card');
              _showServiceModal(context, 'Credit Card', Icons.credit_card_rounded, Colors.pinkAccent);
            },
          );
        case 'Water Bill':
          return _buildActionIcon(
            context: context,
            icon: Icons.water_drop_rounded,
            label: 'Water Bill',
            color: Colors.blue,
            onTap: () {
              _recordUsage('Water Bill');
              _showServiceModal(context, 'Water Bill', Icons.water_drop_rounded, Colors.blue);
            },
          );
        case 'Broadband':
          return _buildActionIcon(
            context: context,
            icon: Icons.wifi_tethering_rounded,
            label: 'Broadband',
            color: Colors.tealAccent,
            onTap: () {
              _recordUsage('Broadband');
              _showServiceModal(context, 'Broadband', Icons.wifi_tethering_rounded, Colors.tealAccent);
            },
          );
        default:
          return _buildActionIcon(
            context: context,
            icon: Icons.bolt_rounded,
            label: 'Electricity',
            color: Colors.orangeAccent,
            onTap: () {
              _recordUsage('Electrical Bill');
              _showServiceModal(context, 'Electrical Bill', Icons.bolt_rounded, Colors.orangeAccent);
            },
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Row(
            children: [
              Text(
                'Quick',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Text(
                '• Smart usage slots',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Fixed Slot 1: Send
            _buildActionIcon(
              context: context,
              icon: Icons.send_rounded,
              label: 'Send',
              color: Colors.blueAccent,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/send_options');
              },
            ),
            // Fixed Slot 2: Scan QR
            _buildActionIcon(
              context: context,
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan QR',
              color: Colors.purpleAccent,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/qr_scanner');
              },
            ),
            // Dynamic Slot 3
            if (top2.isNotEmpty) buildDynamicSlot(top2[0]),
            // Dynamic Slot 4
            if (top2.length > 1) buildDynamicSlot(top2[1]),
          ],
        ),
      ],
    );
  }

  Widget _buildUtilityServicesGrid(BuildContext context) {
    final services = [
      {'key': 'Recharges', 'title': 'Recharges', 'icon': Icons.phone_android_rounded, 'color': Colors.cyan},
      {'key': 'Hotel / Resort', 'title': 'Hotel / Resort', 'icon': Icons.hotel_rounded, 'color': Colors.amber},
      {'key': 'Flight Ticket', 'title': 'Flight Ticket', 'icon': Icons.flight_takeoff_rounded, 'color': Colors.blueAccent},
      {'key': 'EMI Payment', 'title': 'EMI Payment', 'icon': Icons.credit_score_rounded, 'color': Colors.purpleAccent},
      {'key': 'Digital Loan', 'title': 'Digital Loan', 'icon': Icons.account_balance_wallet_rounded, 'color': Colors.greenAccent},
      {'key': 'Electrical Bill', 'title': 'Electrical Bill', 'icon': Icons.bolt_rounded, 'color': Colors.orangeAccent},
      {'key': 'Credit Card', 'title': 'Credit Card', 'icon': Icons.credit_card_rounded, 'color': Colors.pinkAccent},
      {'key': 'Water Bill', 'title': 'Water Bill', 'icon': Icons.water_drop_rounded, 'color': Colors.blue},
      {'key': 'Broadband', 'title': 'Broadband', 'icon': Icons.wifi_tethering_rounded, 'color': Colors.tealAccent},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Utility & Travel Services',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: services.length,
          itemBuilder: (ctx, idx) {
            final svc = services[idx];
            final key = svc['key'] as String;
            final title = svc['title'] as String;
            final icon = svc['icon'] as IconData;
            final color = svc['color'] as Color;

            return GestureDetector(
              onTap: () {
                _recordUsage(key);
                _showServiceModal(context, title, icon, color);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showServiceModal(BuildContext context, String title, IconData icon, Color color) {
    final accountController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accountController,
              decoration: InputDecoration(
                labelText: title.contains('Recharge') ? 'Phone Number / Subscriber ID' : 'Account Number / ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (${ThemeProvider.currentCurrency})',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.maxFinite,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Processing $title payment securely...')),
                  );
                },
                child: const Text('Authorize with Payment Gateway Pin', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
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
              '${isCredit ? '+' : '−'}${ThemeProvider.currentCurrency}${transaction.amount.toStringAsFixed(2)}',
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
                    'No recent transactions',
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
                    'Transaction History',
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
