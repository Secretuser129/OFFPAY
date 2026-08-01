import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/password_service.dart';
import '../services/firebase_service.dart';
import '../models/wallet_model.dart';

class PinSettingsScreen extends StatefulWidget {
  const PinSettingsScreen({super.key});

  @override
  State<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<PinSettingsScreen> {
  bool _hasBalancePin = false;
  bool _hasTransferPin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinStates();
  }

  Future<void> _loadPinStates() async {
    setState(() => _isLoading = true);
    final hasBalance = await PasswordService.hasBalancePin();
    final hasTransfer = await PasswordService.hasTransferPin();
    setState(() {
      _hasBalancePin = hasBalance;
      _hasTransferPin = hasTransfer;
      _isLoading = false;
    });
  }

  Future<void> _showSetPinDialog({required bool isBalancePin}) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureText = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isBalancePin ? 'Set Balance Pin' : 'Set Payment Gateway Pin'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: pinController,
                    obscureText: obscureText,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'New PIN (4-6 digits)',
                      suffixIcon: IconButton(
                        icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setDialogState(() => obscureText = !obscureText);
                        },
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 4) {
                        return 'PIN must be at least 4 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureText,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                    ),
                    validator: (val) {
                      if (val != pinController.text) {
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    
                    try {
                      if (isBalancePin) {
                        await PasswordService.setBalancePin(pinController.text);
                      } else {
                        await PasswordService.setTransferPin(pinController.text);
                      }
                      
                      final wallet = context.read<WalletModel>();
                      // Assuming PasswordService doesn't expose hashPin, we just skip it or pass a dummy
                      await FirebaseService.syncUserProfile(
                        balance: wallet.balance,
                      );
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${isBalancePin ? 'Balance' : 'Transfer'} PIN set successfully')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to set PIN: $e')),
                        );
                      }
                    }
                    
                    _loadPinStates();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removePin({required bool isBalancePin}) async {
    setState(() => _isLoading = true);
    
    try {
      if (isBalancePin) {
        await PasswordService.clearBalancePin();
      } else {
        await PasswordService.clearTransferPin();
      }
      
      if (mounted) {
        final wallet = context.read<WalletModel>();
        await FirebaseService.syncUserProfile(balance: wallet.balance);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isBalancePin ? 'Balance' : 'Transfer'} PIN removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove PIN: $e')),
        );
      }
    }
    
    _loadPinStates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom PIN Security'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    'PIN Protection',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set separate PINs to secure your balance visibility and authorize transfers.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Card 1: Balance View PIN
                  _buildGlassCard(
                    isDark: isDark,
                    borderColor: isDark ? Colors.white.withValues(alpha: 0.15) : theme.primaryColor.withValues(alpha: 0.2),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.16) : theme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(Icons.account_balance_wallet, color: isDark ? Colors.white : theme.primaryColor),
                      ),
                      title: const Text('Balance Pin', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_hasBalancePin ? 'PIN is set' : 'Not configured'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasBalancePin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removePin(isBalancePin: true),
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
                  
                  // Card 2: Payment Gateway Pin
                  _buildGlassCard(
                    isDark: isDark,
                    borderColor: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.2),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: CircleAvatar(
                        backgroundColor: isDark ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
                        child: Icon(Icons.security, color: isDark ? Colors.blueAccent : Colors.blue),
                      ),
                      title: const Text('Payment Gateway Pin', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_hasTransferPin ? 'PIN is set' : 'Not configured'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasTransferPin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _removePin(isBalancePin: false),
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
      // bottomNavigationBar removed for clean full-screen view
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    required bool isDark,
    required Color borderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2C).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
