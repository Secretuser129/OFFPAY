// lib/screens/payment_input_screen.dart

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:provider/provider.dart';
import '../models/wallet_model.dart'; 
import '../services/bluetooth_service.dart';
import '../services/smart_payment_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firebase_service.dart';
import '../services/password_service.dart';
import '../services/theme_service.dart';
import 'payment_success_screen.dart';

class PaymentInputScreen extends StatefulWidget {
  const PaymentInputScreen({super.key});

  @override
  State<PaymentInputScreen> createState() => _PaymentInputScreenState();
}

class _PaymentInputScreenState extends State<PaymentInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Variable to hold the device received from arguments
  fb.BluetoothDevice? recipientDevice;
  String customRecipientName = 'Unknown User';
  bool _isOnlineMode = false;
  bool _isAmountLocked = false;
  
  // Connection State variables
  bool _isConnecting = true;
  bool _isConnected = false;
  String _connectionError = '';
  
  bool _isProcessing = false;
  String? _recipientPhotoBase64;
  bool _hasFetchedPhoto = false;
  bool _hasInitiatedConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OffpayBluetoothService>(context, listen: false).setInPaymentFlow(true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Retrieve the BluetoothDevice or Map passed from DiscoveryScreen/QRScannerScreen
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is fb.BluetoothDevice) {
      recipientDevice = args;
      customRecipientName = args.platformName.isNotEmpty ? args.platformName : 'Unknown User';
    } else if (args is Map<String, dynamic>) {
      if (args['device'] is fb.BluetoothDevice) {
        recipientDevice = args['device'] as fb.BluetoothDevice;
        customRecipientName = recipientDevice!.platformName.isNotEmpty ? recipientDevice!.platformName : 'Unknown User';
      }
      if (args['recipientName'] != null && (args['recipientName'] as String).trim().isNotEmpty) {
        customRecipientName = (args['recipientName'] as String).trim();
      }
      if (args['amount'] != null) {
        final amt = (args['amount'] as num).toDouble();
        if (amt > 0) {
          if (_amountController.text.isEmpty) {
            _amountController.text = amt.toStringAsFixed(2);
          }
          _isAmountLocked = true;
        }
      }
      if (args['isOnlineMode'] == true) {
        _isOnlineMode = true;
      }
    }
    if (!_hasFetchedPhoto && customRecipientName.isNotEmpty) {
      _hasFetchedPhoto = true;
      final targetId = recipientDevice?.remoteId.str ?? customRecipientName;
      FirebaseService.fetchUserPhotoBase64(targetId).then((base64) {
        if (base64 != null && mounted) {
          setState(() => _recipientPhotoBase64 = base64);
        } else if (customRecipientName != targetId) {
          FirebaseService.fetchUserPhotoBase64(customRecipientName).then((base64Name) {
            if (base64Name != null && mounted) {
              setState(() => _recipientPhotoBase64 = base64Name);
            }
          });
        }
      });
    }
    // Handle the edge case where the device is null
    if (recipientDevice == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context); // Go back if no device is found
      });
    } else {
      if (_isOnlineMode) {
        setState(() {
          _isConnecting = false;
          _isConnected = true;
        });
      } else if (!_hasInitiatedConnection) {
        _hasInitiatedConnection = true;
        // Initiate background connection to the recipient
        _connectToRecipient();
      }
    }
  }

  Future<void> _connectToRecipient() async {
    setState(() {
      _isConnecting = true;
      _connectionError = '';
    });

    final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
    final connected = await bluetoothService.connectToDevice(recipientDevice!);

    if (!mounted) return;

    setState(() {
      _isConnecting = false;
      _isConnected = connected;
      if (!connected) {
        _connectionError = 'Failed to connect. Please make sure the receiver is nearby.';
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // --- Payment Processing Logic (Integrated Bluetooth Call) ---
  Future<void> _processPayment() async {
    // Ensure validation passes and a device is selected
    if (!_formKey.currentState!.validate() || recipientDevice == null) {
      return;
    }

    final hasPin = await PasswordService.hasTransferPin();
    if (hasPin) {
      final authorized = await _showTransferPinDialog();
      if (!authorized) return;
    }

    setState(() => _isProcessing = true);

    final double amount = double.parse(_amountController.text);
    final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
    final walletModel = Provider.of<WalletModel>(context, listen: false);

    // Find the real RSSI from the discovered devices list
    int currentRssi = -70; // Default fallback
    if (!_isOnlineMode) {
      try {
        final discoveredDevice = bluetoothService.discoveredDevices
            .firstWhere((d) => d.device.remoteId == recipientDevice!.remoteId);
        currentRssi = discoveredDevice.rssi;
      } catch (_) {
        // Ignore if device not found in active list
      }
    }

    bool success = false;
    
    if (_isOnlineMode) {
      success = await FirebaseService.executeOnlineTransfer(
        senderWallet: walletModel,
        recipientDeviceId: recipientDevice!.remoteId.str,
        amount: amount,
      );
      if (!success) {
        // Fallback to Smart Offline Transfer if online QR network transfer encountered an issue
        success = await SmartPaymentManager.executeSmartTransfer(
          bluetoothService: bluetoothService,
          walletModel: walletModel,
          recipientDevice: recipientDevice!,
          amount: amount,
          currentRssi: currentRssi,
        );
      }
    } else {
      // 1. EXECUTE SMART TRANSFER via Invisible Manager
      success = await SmartPaymentManager.executeSmartTransfer(
        bluetoothService: bluetoothService,
        walletModel: walletModel,
        recipientDevice: recipientDevice!,
        amount: amount,
        currentRssi: currentRssi, 
      );
    }

    if (success) {
      if (mounted) setState(() => _isProcessing = false);
      final recipientName = customRecipientName.isNotEmpty 
          ? customRecipientName 
          : 'Unknown User';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
            amount: amount, 
            recipientName: recipientName,
          ),
        ),
      );
    } else {
      if (mounted) setState(() => _isProcessing = false);
      // 4. Transaction completely failed (even mesh routing failed)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Payment failed. Could not route transaction securely.'), backgroundColor: Colors.red),
      );
    }
  }

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    // Safely check for recipientDevice again here for the UI build
    if (recipientDevice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid recipient device.')));
    }

    final walletModel = Provider.of<WalletModel>(context);
    final device = recipientDevice!;
    final displayRecipientName = customRecipientName.isNotEmpty 
        ? customRecipientName 
        : (device.platformName.isNotEmpty ? device.platformName : 'Unknown User');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details'), elevation: 0),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: ListView(
            children: <Widget>[
              // --- Server Connection Status Banner (ONLY in QR Server Mode) ---
              if (_isOnlineMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are connected with server (QR Server Mode)',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // --- Connection Status Banner (Fixed Height 60px to prevent shaking) ---
              SizedBox(
                height: 60,
                child: _isConnecting && !_isOnlineMode
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connecting to ${displayRecipientName}...',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (!_isConnected
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _connectionError,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _connectToRecipient,
                                  child: const Text('Retry', style: TextStyle(color: Colors.red)),
                                )
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Connected securely to ${displayRecipientName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          )),
              ),
              const SizedBox(height: 12),
              // --- End Status Banner ---

              // Recipient Info Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryColor.withValues(alpha: 0.1), theme.primaryColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primaryColor,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: _recipientPhotoBase64 != null
                            ? CircleAvatar(
                                radius: 24,
                                backgroundImage: MemoryImage(base64Decode(_recipientPhotoBase64!)),
                              )
                            : const Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sending to',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayRecipientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'OFFPAY Offline Receiver • Trusted Device',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Amount Input Field
              Text(
                'Enter Amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                readOnly: _isAmountLocked,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${ThemeProvider.currentCurrency})',
                  labelStyle: TextStyle(color: theme.hintColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: theme.primaryColor),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount.';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount.';
                  }
                  if (amount > walletModel.balance) {
                    return 'Insufficient balance. Available: ${ThemeProvider.currentCurrency}${walletModel.balance.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
              if (_isAmountLocked) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Amount locked by recipient QR code (${ThemeProvider.currentCurrency}${_amountController.text}). Cannot be changed.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Balance Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : theme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Available Balance',
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${ThemeProvider.currentCurrency}${walletModel.balance.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.primaryColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Pay Now Button
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('Proceed to Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isConnected && !_isConnecting ? _processPayment : null, // Disabled if not connected
              ),

              const SizedBox(height: 12),

              // Cancel Button
              OutlinedButton(
                onPressed: () {
                  // Ensure we cleanly disconnect if user cancels
                  if (_isConnected && recipientDevice != null) {
                    recipientDevice!.disconnect().catchError((_) {});
                  }
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
              ),
            ].animate(interval: 50.ms).fade().slideY(begin: 0.1, end: 0),
          ),
        ),
          ),
          if (_isProcessing)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigoAccent.withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const SizedBox(
                                width: 70,
                                height: 70,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                                ),
                              ),
                              Icon(Icons.shield_rounded, color: Colors.indigoAccent.shade100, size: 32)
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: const Duration(milliseconds: 800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Processing Transfer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Securing cryptographic proof & signing transaction...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _showTransferPinDialog() async {
    final pinController = TextEditingController();
    bool obscureText = true;
    final formKey = GlobalKey<FormState>();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Payment Gateway Pin', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your secure PIN to authorize this offline payment.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pinController,
                      obscureText: obscureText,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Enter 4-6 Digit PIN',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => obscureText = !obscureText),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 4) return 'PIN must be at least 4 digits';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final isValid = await PasswordService.verifyTransferPin(pinController.text);
                      if (isValid) {
                        Navigator.pop(context, true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incorrect PIN. Payment Unauthorized.'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Authorize', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }
}
