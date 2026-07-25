// lib/screens/device_scan_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import '../services/bluetooth_service.dart';

class DeviceScanScreen extends StatelessWidget {
  const DeviceScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Devices'),
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
            return const Center(child: CircularProgressIndicator());
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
        return ListTile(
          title: Text(item.name),
          subtitle: Text('ID: ${item.id} | RSSI: ${item.rssi} dBm'),
          trailing: ElevatedButton(
            onPressed: () => _connectAndRedirect(context, item.device),
            child: const Text('Connect'),
          ),
        );
      },
    );
  }

  Future<void> _connectAndRedirect(BuildContext context, fb.BluetoothDevice device) async {
    final service = Provider.of<OffpayBluetoothService>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${device.platformName}...')),
    );

    final txId = await service.connectAndTransfer(device, 10.00);

    if (txId != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const TransactionSuccessScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection/Transfer failed!')),
      );
    }
  }
}

class TransactionSuccessScreen extends StatelessWidget {
  const TransactionSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Complete')),
      body: const Center(child: Text('Data transferred successfully!')),
    );
  }
}
