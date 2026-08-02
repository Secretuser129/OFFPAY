import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;

import '../models/trusted_contact.dart';
import '../services/firebase_service.dart';
import '../services/profile_service.dart';
import 'payment_input_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // Use 'late' initialization
  late MobileScannerController cameraController;
  bool _scannedOnce = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Optimized for ultra-fast QR detection without live camera bitmap lag
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
  
  // --- 💡 Function to pick and scan QR code from album/screenshots ---
  Future<void> _scanFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      final inputImage = mlkit.InputImage.fromFilePath(pickedFile.path);
      final barcodeScanner = mlkit.BarcodeScanner();
      final List<mlkit.Barcode> barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();

      if (barcodes.isNotEmpty) {
        for (final barcode in barcodes) {
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            _scannedOnce = true;
            _handleQRCode(barcode.rawValue!);
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect a valid QR code in this image.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Gallery scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Recipient QR Code'),
        elevation: 0,
        actions: [
          // 2. ALBUM/GALLERY OPTION
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _scanFromGallery, // Call the new function
          ),
          
          // 3. FLASHLIGHT TOGGLE (Dynamically changing icon)
          ValueListenableBuilder(
            valueListenable: cameraController,
            builder: (context, state, child) {
              final icon = state.torchState == TorchState.off
                  ? Icons.flashlight_off
                  : Icons.flashlight_on;
              return IconButton(
                icon: Icon(icon),
                onPressed: () => cameraController.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!_scannedOnce) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    // Prevent further scanning
                    _scannedOnce = true;
                    // Stop camera to prevent double-scans
                    cameraController.stop(); 
                    _handleQRCode(barcode.rawValue!);
                  }
                }
              }
            },
          ),

          // Overlay with scanning frame
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top overlay
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.75),
                  ),
                ),

                // Middle with clean curved border scanner frame
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 2.5),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),

                // Bottom overlay with clean instruction
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 20,
                              color: Colors.white,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Align QR code within border',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cancel button
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Cancel Scan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      // bottomNavigationBar removed for clean full-screen view
    );
  }

  // --- 4. Encrypted Navigation Handler ---
  void _handleQRCode(String qrData) {
    // Check if this is the Receiver Bluetooth Connect QR Code
    final btData = ProfileService.parseBluetoothQrPayload(qrData);
    if (btData != null) {
      _showBluetoothReceiverPopup(
        deviceId: btData['id'] as String,
        userName: btData['name'] as String,
        macAddress: btData['mac'] as String,
        avatarIndex: btData['avatar'] as int,
        embeddedPhoto: btData['photo'] as String?,
      );
      return;
    }

    // Otherwise, it is My QR or standard server QR code — connect with server through (online mode)
    final decrypted = ProfileService.decryptQrPayload(qrData);
    if (decrypted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or untrusted OFFPAY QR code.'), backgroundColor: Colors.red),
      );
      setState(() => _scannedOnce = false);
      try {
        cameraController.start();
      } catch (_) {}
      return;
    }

    final targetDeviceId = decrypted['id'] ?? qrData;
    final String recipientName = (decrypted['name'] != null && decrypted['name']!.trim().isNotEmpty)
        ? decrypted['name']!.trim()
        : 'Unknown User';
    final double? setAmount = double.tryParse(decrypted['amount'] ?? '0.0');
    final device = fb.BluetoothDevice(remoteId: fb.DeviceIdentifier(targetDeviceId));

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const PaymentInputScreen(),
        settings: RouteSettings(arguments: {
          'device': device,
          'recipientName': recipientName,
          'amount': setAmount ?? 0.0,
          'isOnlineMode': true, // Server mode!
        }),
      ),
    );
  }

  void _showBluetoothReceiverPopup({
    required String deviceId,
    required String userName,
    required String macAddress,
    required int avatarIndex,
    String? embeddedPhoto,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _BluetoothReceiverPopupDialog(
        deviceId: deviceId,
        userName: userName,
        macAddress: macAddress,
        avatarIndex: avatarIndex,
        embeddedPhoto: embeddedPhoto,
        onConnect: () {
          Navigator.of(ctx).pop();
          final targetId = macAddress.isNotEmpty ? macAddress : deviceId;
          final device = fb.BluetoothDevice(remoteId: fb.DeviceIdentifier(targetId));
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const PaymentInputScreen(),
              settings: RouteSettings(
                arguments: {
                  'device': device,
                  'recipientName': userName,
                  'amount': 0.0,
                  'isOnlineMode': false, // Connect directly via Bluetooth BLE!
                },
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _scannedOnce = false);
        try {
          cameraController.start();
        } catch (_) {}
      }
    });
  }
}

class _BluetoothReceiverPopupDialog extends StatefulWidget {
  final String deviceId;
  final String userName;
  final String macAddress;
  final int avatarIndex;
  final String? embeddedPhoto;
  final VoidCallback onConnect;

  const _BluetoothReceiverPopupDialog({
    required this.deviceId,
    required this.userName,
    required this.macAddress,
    required this.avatarIndex,
    this.embeddedPhoto,
    required this.onConnect,
  });

  @override
  State<_BluetoothReceiverPopupDialog> createState() => _BluetoothReceiverPopupDialogState();
}

class _BluetoothReceiverPopupDialogState extends State<_BluetoothReceiverPopupDialog> {
  String? _photoBase64;
  bool _isTrustedSaved = false;

  static const List<IconData> _avatars = [
    Icons.person,
    Icons.account_balance_wallet,
    Icons.shield,
    Icons.bolt,
    Icons.star,
    Icons.verified_user,
  ];

  @override
  void initState() {
    super.initState();
    _photoBase64 = widget.embeddedPhoto;
    _checkTrustedContact();
    _fetchPhotoIfNeeded();
  }

  void _checkTrustedContact() {
    setState(() {
      _isTrustedSaved = TrustedContactService.isContactSaved(widget.deviceId);
    });
  }

  Future<void> _fetchPhotoIfNeeded() async {
    if (_photoBase64 == null) {
      final base64 = await FirebaseService.fetchUserPhotoBase64(widget.deviceId);
      if (base64 != null && mounted) {
        setState(() => _photoBase64 = base64);
      }
    }
  }

  Future<void> _addToTrustedContacts() async {
    if (_isTrustedSaved) return;
    await TrustedContactService.addContact(
      TrustedContact(
        name: widget.userName,
        deviceId: widget.deviceId,
        addedOn: DateTime.now(),
        totalTransactions: 0,
      ),
    );
    if (mounted) {
      setState(() => _isTrustedSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${widget.userName} added to Trusted Contacts!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _avatars[widget.avatarIndex.clamp(0, _avatars.length - 1)];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    'BLUETOOTH RECEIVER DETECTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profile Picture with glowing ring
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.primaryColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                backgroundImage: _photoBase64 != null
                    ? MemoryImage(base64Decode(_photoBase64!))
                    : null,
                child: _photoBase64 == null
                    ? Icon(icon, size: 44, color: theme.primaryColor)
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // User Name
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Device Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Device ID: ${widget.deviceId}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                    ),
                  ),
                  if (widget.macAddress.isNotEmpty && widget.macAddress != 'Loading...') ...[
                    const SizedBox(height: 2),
                    Text(
                      'BLE Address: ${widget.macAddress}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Connect Button (Primary)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth_connected, size: 20),
                label: const Text(
                  'Connect via Bluetooth',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: widget.onConnect,
              ),
            ),
            const SizedBox(height: 12),

            // Add in Trusted Contact Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  _isTrustedSaved ? Icons.check_circle : Icons.person_add_alt_1,
                  color: _isTrustedSaved ? Colors.green : theme.primaryColor,
                  size: 18,
                ),
                label: Text(
                  _isTrustedSaved ? 'Trusted Contact Saved' : 'Add to Trusted Contacts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isTrustedSaved ? Colors.green : theme.primaryColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(
                    color: _isTrustedSaved ? Colors.green : theme.primaryColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isTrustedSaved ? null : _addToTrustedContacts,
              ),
            ),
            const SizedBox(height: 8),

            // Close TextButton
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}