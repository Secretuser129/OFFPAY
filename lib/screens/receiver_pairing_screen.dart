import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import '../services/bluetooth_service.dart';

class ReceiverPairingScreen extends StatefulWidget {
  const ReceiverPairingScreen({super.key});

  @override
  State<ReceiverPairingScreen> createState() => _ReceiverPairingScreenState();
}

class _ReceiverPairingScreenState extends State<ReceiverPairingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<OffpayBluetoothService>(context, listen: false);
      service.startScan(timeout: const Duration(seconds: 15));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Senders (Pairing Mode)'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Consumer<OffpayBluetoothService>(
            builder: (context, service, child) {
              if (service.isScanning) {
                return IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: service.stopScan,
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: service.startScan,
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<OffpayBluetoothService>(
        builder: (context, service, child) {
          if (service.isScanning && service.discoveredDevices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text('Scanning for OFFPAY senders...'),
                ],
              ),
            );
          }
          if (service.discoveredDevices.isEmpty) {
            return const Center(child: Text('No devices found. Tap refresh to scan.'));
          }
          return _buildDeviceList(context, service.discoveredDevices);
        },
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, List<DiscoveredDevice> devices) {
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final item = devices[index];
        final bool isOffpay = item.isOffpayUser;
        
        return ListTile(
          leading: Icon(
            Icons.bluetooth,
            color: isOffpay ? Colors.indigo : Colors.grey,
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: isOffpay ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text('ID: ${item.id} | RSSI: ${item.rssi} dBm'),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOffpay ? Colors.indigo : Colors.grey.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _initiatePairing(context, item.device),
            child: const Text('Pair'),
          ),
        );
      },
    );
  }

  Future<void> _initiatePairing(BuildContext context, fb.BluetoothDevice device) async {
    final service = Provider.of<OffpayBluetoothService>(context, listen: false);
    
    // Stop scanning before pairing
    await service.stopScan();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Requesting pairing with ${device.platformName}...'),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      // Connect first: flutter_blue_plus requires the device to be connected before creating a bond
      await device.connect(autoConnect: false, license: fb.License.free).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      
      // Force Android OS to show the 6-digit PIN popup
      await device.createBond();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing initiated! Check screen for PIN.'),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Navigate back after a short delay so user can handle the OS popup
      Future.delayed(const Duration(seconds: 2), () {
        // We disconnect in background so it doesn't hold the connection
        device.disconnect().catchError((_) {});
        if (mounted) Navigator.pop(context);
      });
      
    } catch (e) {
      debugPrint('Pairing error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initiate pairing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
