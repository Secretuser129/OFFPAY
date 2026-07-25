import 'package:flutter/material.dart';
import '../services/password_service.dart';
import '../services/firebase_service.dart';
import '../services/theme_service.dart';
import '../models/wallet_model.dart';
import 'package:provider/provider.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _hasBalancePin = false;
  bool _hasTransferPin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinStates();
  }

  Future<void> _loadPinStates() async {
    final hasBal = await PasswordService.hasBalancePin();
    final hasTx = await PasswordService.hasTransferPin();
    if (mounted) {
      setState(() {
        _hasBalancePin = hasBal;
        _hasTransferPin = hasTx;
        _isLoading = false;
      });
    }
  }

  void _showSetPinDialog({required bool isBalancePin}) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureText = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isBalancePin ? 'Set Balance Check PIN' : 'Set Transfer Confirmation PIN'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscureText,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Enter 4-6 Digit PIN',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureText = !obscureText),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 4) {
                      return 'PIN must be at least 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: obscureText,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (v) {
                    if (v != pinController.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),
              ],
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
                  final pin = pinController.text.trim();
                  if (isBalancePin) {
                    await PasswordService.setBalancePin(pin);
                  } else {
                    await PasswordService.setTransferPin(pin);
                  }
                  final walletModel = Provider.of<WalletModel>(context, listen: false);
                  FirebaseService.syncUserProfile(
                    balance: walletModel.balance,
                    pinHash: pin,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadPinStates();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${isBalancePin ? "Balance" : "Transfer"} PIN set & synced to cloud!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _removePin({required bool isBalancePin}) async {
    if (isBalancePin) {
      await PasswordService.clearBalancePin();
    } else {
      await PasswordService.clearTransferPin();
    }
    _loadPinStates();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isBalancePin ? "Balance" : "Transfer"} PIN removed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Security'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // 1. App Appearance & Theme Toggle Section
                  const Text(
                    'App Appearance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch between Dark Mode and Light Mode.',
                    style: TextStyle(color: theme.hintColor, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      final isDark = themeProvider.isDarkMode(context);
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? Colors.purple.withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            child: Icon(
                              isDark ? Icons.dark_mode : Icons.light_mode,
                              color: isDark ? Colors.purple.shade300 : Colors.amber.shade800,
                            ),
                          ),
                          title: Text(
                            isDark ? 'AMOLED Dark Mode' : 'Light Mode',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isDark ? 'Pure black background enabled' : 'Clean light theme enabled',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Switch(
                            value: isDark,
                            activeThumbColor: Colors.indigo,
                            onChanged: (bool value) {
                              themeProvider.toggleTheme(value);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // 2. Custom PIN Security Section
                  const Text(
                    'Custom PIN Protection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set separate PINs to hide/view your balance and authorize offline transfers.',
                    style: TextStyle(color: theme.hintColor, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Balance Check PIN Card
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                        child: const Icon(Icons.account_balance_wallet, color: Colors.indigo),
                      ),
                      title: const Text(
                        'Balance View PIN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _hasBalancePin
                            ? 'PIN active. Required when toggling balance visibility.'
                            : 'Not set. Anyone can view balance.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasBalancePin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removePin(isBalancePin: true),
                              tooltip: 'Remove PIN',
                            ),
                          ElevatedButton(
                            onPressed: () => _showSetPinDialog(isBalancePin: true),
                            child: Text(_hasBalancePin ? 'Change' : 'Set PIN'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Confirm Transfer Money PIN Card
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        child: const Icon(Icons.security, color: Colors.green),
                      ),
                      title: const Text(
                        'Transfer Authorization PIN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _hasTransferPin
                            ? 'PIN active. Required before completing offline money transfer.'
                            : 'Not set. Money transfers proceed immediately.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasTransferPin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removePin(isBalancePin: false),
                              tooltip: 'Remove PIN',
                            ),
                          ElevatedButton(
                            onPressed: () => _showSetPinDialog(isBalancePin: false),
                            child: Text(_hasTransferPin ? 'Change' : 'Set PIN'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
