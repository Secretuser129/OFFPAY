import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trusted_contact.dart';
import '../models/wallet_model.dart';
import '../services/receipt_service.dart';
import '../services/reward_service.dart';
import '../widgets/global_apple_dock.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<TrustedContact> _allContacts = [];
  List<TrustedContact> _filteredContacts = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await TrustedContactService.init();
    _loadContacts();
  }

  void _loadContacts() {
    final contacts = TrustedContactService.getContacts();
    setState(() {
      _allContacts = contacts;
      _filteredContacts = contacts;
    });
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((c) =>
            c.name.toLowerCase().contains(query.toLowerCase()) ||
            c.deviceId.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  void _confirmDelete(TrustedContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to remove ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TrustedContactService.removeContact(contact.deviceId);
              _loadContacts();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.7) ?? Colors.white70),
                ),
                style: TextStyle(color: theme.appBarTheme.foregroundColor ?? Colors.white),
                onChanged: _filterContacts,
              )
            : const Text('Trusted Contacts'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterContacts('');
                }
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/contacts'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _allContacts.isEmpty
            ? Center(
                key: const ValueKey('empty'),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.contacts_outlined,
                        size: 80,
                        color: theme.primaryColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No trusted contacts yet. Save contacts from transaction details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.hintColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.9, 0.9))
            : ListView.builder(
                key: const ValueKey('list'),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isDark ? BorderSide(color: Colors.indigo.withValues(alpha: 0.3)) : BorderSide.none,
                    ),
                    color: theme.cardTheme.color,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.16) : theme.primaryColor,
                          foregroundColor: Colors.white,
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device: ${contact.deviceId}',
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                              Text(
                                '${contact.totalTransactions} transactions',
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.send, color: theme.primaryColor),
                              onPressed: () => _showPaymentModeModal(contact),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDelete(contact),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: (100 * index).ms).fade(duration: 500.ms).slideX(begin: 0.1, end: 0);
                },
              ),
      ),
      // bottomNavigationBar removed for clean full-screen view
    );
  }

  void _showPaymentModeModal(TrustedContact contact) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                    child: const Icon(Icons.verified_user, color: Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay ${contact.name}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Device ID: ${contact.deviceId}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_done_outlined, color: Colors.green),
                ),
                title: const Text(
                  'Online Server Pay (Priority Match)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Matches Device ID on Server • Instant Verify & Sync Account'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showOnlinePayDialog(contact);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_searching, color: Colors.indigo),
                ),
                title: const Text(
                  'Offline BLE Direct Pay',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Connect via Bluetooth Low Energy (<100ms offline transfer)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  final fb.BluetoothDevice device = fb.BluetoothDevice.fromId(contact.deviceId);
                  Navigator.pushNamed(
                    context,
                    '/payment_input',
                    arguments: {'device': device, 'recipientName': contact.name},
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOnlinePayDialog(TrustedContact contact) {
    final TextEditingController amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.security, color: Colors.green),
              const SizedBox(width: 8),
              Text('Server Verified Pay • ${contact.name}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Matched Device ID on Server:\n${contact.deviceId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final double? amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount.')),
                  );
                  return;
                }
                final walletModel = Provider.of<WalletModel>(context, listen: false);
                if (walletModel.balance < amount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insufficient balance.')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final String txId = const Uuid().v4();
                final bool success = await walletModel.sendMoney(
                  amount,
                  contact.deviceId,
                  status: 'SUCCESS',
                  transactionId: txId,
                );

                if (success) {
                  await TrustedContactService.incrementTransactions(contact.deviceId);
                  await RewardService.generateRewardForTransaction(transactionId: txId, amount: amount);
                  _loadContacts();

                  if (mounted) {
                    _showServerSuccessModal(contact, amount, txId);
                  }
                }
              },
              child: const Text('Verify & Pay'),
            ),
          ],
        );
      },
    );
  }

  void _showServerSuccessModal(TrustedContact contact, double amount, String txId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Server-Verified Payment Done!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '₹$amount successfully sent to ${contact.name}\nMatched Server Device ID: ${contact.deviceId}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Receipt'),
                      onPressed: () {
                        ReceiptService.generateAndShareReceipt(
                          amount: amount,
                          recipientId: contact.deviceId,
                          transactionId: txId,
                          timestamp: DateTime.now(),
                          isCredit: false,
                          status: 'SUCCESS',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
