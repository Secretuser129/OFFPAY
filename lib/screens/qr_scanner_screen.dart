import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

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

          // Overlay with scanning frame (Your existing UI code)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top overlay
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),

                // Middle with scanner frame
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 3),
                        color: Colors.transparent,
                      ),
                      child: Stack(
                        children: [
                          // Corner indicators (simplified for brevity)
                          ..._buildScannerCorners(context), 
                          
                          // Scanning line animation
                          Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: -1, end: 1),
                              duration: const Duration(seconds: 2),
                              curve: Curves.linear,
                              onEnd: () {},
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, value * 100),
                                  child: Container(
                                    height: 2,
                                    width: double.infinity,
                                    color: Colors.green.withValues(alpha: 0.7),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom overlay
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.qr_code_2,
                            size: 40,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Position QR code within the frame',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cancel button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel Scan'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function for corner indicators (to clean up the build method)
  List<Widget> _buildScannerCorners(BuildContext context) {
    const double cornerSize = 30;
    const double cornerWidth = 3;
    const Color cornerColor = Colors.green;

    return [
      _buildCornerIndicator(top: 10, left: 10, border: const Border(top: BorderSide(color: cornerColor, width: cornerWidth), left: BorderSide(color: cornerColor, width: cornerWidth)), size: cornerSize),
      _buildCornerIndicator(top: 10, right: 10, border: const Border(top: BorderSide(color: cornerColor, width: cornerWidth), right: BorderSide(color: cornerColor, width: cornerWidth)), size: cornerSize),
      _buildCornerIndicator(bottom: 10, left: 10, border: const Border(bottom: BorderSide(color: cornerColor, width: cornerWidth), left: BorderSide(color: cornerColor, width: cornerWidth)), size: cornerSize),
      _buildCornerIndicator(bottom: 10, right: 10, border: const Border(bottom: BorderSide(color: cornerColor, width: cornerWidth), right: BorderSide(color: cornerColor, width: cornerWidth)), size: cornerSize),
    ];
  }

  // Helper widget for corner indicators
  Widget _buildCornerIndicator({double? top, double? bottom, double? left, double? right, required Border border, required double size}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(border: border),
      ),
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
        }),
      ),
    );
  }
}