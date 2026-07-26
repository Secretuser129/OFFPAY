import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

import '../services/profile_service.dart';
import 'payment_input_screen.dart';
import '../widgets/global_apple_dock.dart';

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
    // Initialize with settings for scanning from gallery
    cameraController = MobileScannerController(
      // Ensure this is true to allow image picking to work smoothly
      returnImage: true, 
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
  
  // --- 💡 Function to pick and scan QR code from album ---
  Future<void> _scanFromGallery() async {
    // 1. Pick the image from the device's gallery
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final BarcodeCapture? capture = await cameraController.analyzeImage(pickedFile.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        if (!_scannedOnce) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              _scannedOnce = true;
              cameraController.stop(); 
              _handleQRCode(barcode.rawValue!);
              return; 
            }
          }
        }
      } else {
        // Show an error if the image was picked but scanning failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find a valid QR code in the image.')),
          );
        }
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
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/qr_scanner'),
    );
  }

  // --- 4. Encrypted Navigation Handler ---
  void _handleQRCode(String qrData) {
    final decrypted = ProfileService.decryptQrPayload(qrData);
    if (decrypted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or untrusted OFFPAY QR code.'), backgroundColor: Colors.red),
      );
      setState(() => _scannedOnce = false);
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
          'isOnlineMode': true,
        }),
      ),
    );
  }
}