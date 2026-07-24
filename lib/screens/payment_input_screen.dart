// lib/screens/payment_input_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:provider/provider.dart';
import '../models/wallet_model.dart'; 
import '../services/bluetooth_service.dart';
import '../services/firebase_service.dart';
// Assuming your payment success screen is here


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
      if (args['amount'] != null && _amountController.text.isEmpty) {
        final amt = (args['amount'] as num).toDouble();
        if (amt > 0) {
          _amountController.text = amt.toStringAsFixed(2);
        }
      }
    }
    // Handle the edge case where the device is null
    if (recipientDevice == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context); // Go back if no device is found
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // --- Payment Processing Logic (Integrated Bluetooth Call) ---
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.indigo),
            const SizedBox(height: 15),
            Text('Connecting to ${recipientDevice!.platformName}...'),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    // Ensure validation passes and a device is selected
    if (!_formKey.currentState!.validate() || recipientDevice == null) {
      return;
    }

    final double amount = double.parse(_amountController.text);
    final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
    final walletModel = Provider.of<WalletModel>(context, listen: false);

    // Show loading dialog
    _showLoadingDialog();

    // 1. EXECUTE BLUETOOTH CONNECTION AND TRANSFER (The main fix)
    bool success = await bluetoothService.connectAndTransfer(recipientDevice!, amount);

    // Dismiss the loading dialog using the context of the payment screen
    Navigator.of(context).pop(); 

    if (success) {
      try {
        // 2. Debit money locally (only if BLE transfer succeeded)
        await walletModel.sendMoney(amount, recipientDevice!.remoteId.str, status: 'PENDING');
        
        // 3. Update Server Cloud Ledger automatically in background
        FirebaseService.syncWithFirebase(walletModel).catchError((_) => <String, dynamic>{});

        // 4. Navigate to Success Screen
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
      } catch (e) {
        // Handle local debit failure (e.g., if sendMoney throws)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating wallet. Payment may have been sent.'), backgroundColor: Colors.red),
        );
      }

    } else {
      // 4. Transaction failed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Payment failed. Could not connect securely/transfer data.'), backgroundColor: Colors.red),
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
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
                        child: const Icon(Icons.person, color: Colors.white, size: 32),
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
                        'Device ID: ${device.remoteId.str}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: TextStyle(color: theme.hintColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, color: theme.primaryColor),
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
                    return 'Insufficient balance. Available: ₹${walletModel.balance.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),

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
                      '₹${walletModel.balance.toStringAsFixed(2)}',
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
                onPressed: _processPayment, // Call the integrated function
              ),

              const SizedBox(height: 12),

              // Cancel Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dummy Payment Success Screen (Ensure you have this file)
class PaymentSuccessScreen extends StatelessWidget {
  final double amount;
  final String recipientName;
  
  const PaymentSuccessScreen({required this.amount, required this.recipientName, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Success'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text('Payment Sent!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.green),
              ),
              const SizedBox(height: 20),
              Text('Successfully transferred to: $recipientName', style: TextStyle(fontSize: 18, color: Colors.grey.shade700), textAlign: TextAlign.center),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}