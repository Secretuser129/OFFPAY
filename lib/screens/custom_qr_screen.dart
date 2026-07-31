import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/profile_service.dart';

class CustomQrScreen extends StatefulWidget {
  const CustomQrScreen({super.key});

  @override
  State<CustomQrScreen> createState() => _CustomQrScreenState();
}

class _CustomQrScreenState extends State<CustomQrScreen> {
  String deviceId = 'OFFPAY-LOADING';
  String userName = 'OFFPAY User';
  String encryptedQrPayload = '';
  double? _customAmount;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final id = await ProfileService.getDeviceId();
    final name = await ProfileService.getUserName();
    if (mounted) {
      setState(() {
        deviceId = id;
        userName = name;
      });
      _regenerateQrPayload(id, name, _customAmount);
    }
  }

  void _regenerateQrPayload(String id, String name, double? amt) {
    final qrData = ProfileService.encryptQrPayload(
      deviceId: id,
      userName: name,
      amount: amt ?? 0.0,
    );
    setState(() {
      encryptedQrPayload = qrData;
    });
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val.trim());
    final newAmount = (parsed != null && parsed > 0) ? parsed : null;
    if (_customAmount == newAmount) return;
    setState(() {
      _customAmount = newAmount;
    });
    _regenerateQrPayload(deviceId, userName, _customAmount);
  }

  void _setPresetAmount(double amt) {
    _amountController.text = amt.toStringAsFixed(0);
    _onAmountChanged(amt.toStringAsFixed(0));
  }

  void _clearCustomAmount() {
    _amountController.clear();
    _onAmountChanged('');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Amount QR'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'QR Code for $userName',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set an amount below to lock it into the scanned QR code',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Custom Amount Input Section ──────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note, color: Colors.indigo),
                            SizedBox(width: 6),
                            Text(
                              'Set Amount',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        if (_customAmount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '₹${_customAmount!.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.currency_rupee, size: 20, color: Colors.indigo),
                        suffixIcon: _amountController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearCustomAmount,
                              )
                            : null,
                        hintText: 'Enter amount (e.g. 250)',
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E2A) : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _onAmountChanged,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: const Text('₹100'),
                            onPressed: () => _setPresetAmount(100),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('₹200'),
                            onPressed: () => _setPresetAmount(200),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('₹500'),
                            onPressed: () => _setPresetAmount(500),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('₹1000'),
                            onPressed: () => _setPresetAmount(1000),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Encrypted QR View (Fixed Personal QR by default, Locked Amount QR when set)
            encryptedQrPayload.isNotEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        QrImageView(
                          data: encryptedQrPayload,
                          size: 240.0,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          dataModuleStyle: const QrDataModuleStyle(
                            color: Colors.black,
                            dataModuleShape: QrDataModuleShape.square,
                          ),
                          eyeStyle: const QrEyeStyle(
                            color: Colors.black,
                            eyeShape: QrEyeShape.square,
                          ),
                          embeddedImage: const AssetImage('assets/images/bluetooth_black.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(44, 44),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              (_customAmount != null && _customAmount! > 0) ? Icons.lock : Icons.verified_user,
                              size: 14,
                              color: (_customAmount != null && _customAmount! > 0) ? Colors.green : theme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (_customAmount != null && _customAmount! > 0)
                                  ? 'Encrypted QR Locked at ₹${_customAmount!.toStringAsFixed(2)}'
                                  : 'Fixed Personal Payment QR (Any Amount)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: (_customAmount != null && _customAmount! > 0) ? Colors.green : theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 64,
                          color: theme.hintColor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No Amount Set Yet',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter an amount above or pick a quick chip to generate a locked payment QR code.',
                          style: TextStyle(fontSize: 13, color: theme.hintColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 24),

            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
      // bottomNavigationBar removed for clean full-screen view
    );
  }
}
