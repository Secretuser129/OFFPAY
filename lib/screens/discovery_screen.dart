import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/bluetooth_service.dart';
import '../services/profile_service.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothService = Provider.of<OffpayBluetoothService>(context, listen: false);
      if (!bluetoothService.isScanning) {
        bluetoothService.startScan();
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OffpayBluetoothService>(
      builder: (context, bluetoothService, child) {
        final theme = Theme.of(context);
        final primaryColor = theme.primaryColor;
        final discovered = bluetoothService.discoveredDevices;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Find Payment Recipient'),
            elevation: 0,
            actions: [
              IconButton(
                icon: bluetoothService.isScanning ? const Icon(Icons.stop) : const Icon(Icons.refresh),
                onPressed: bluetoothService.isScanning ? bluetoothService.stopScan : bluetoothService.startScan,
                tooltip: bluetoothService.isScanning ? 'Stop Scanning' : 'Scan Again',
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              // Bluetooth Disabled Warning Banner
              if (!bluetoothService.isBluetoothOn)
                Container(
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_disabled, color: Colors.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Bluetooth is turned off on this device.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => bluetoothService.enableBluetoothRadio(),
                        child: const Text('Turn On'),
                      ),
                    ],
                  ),
                ),

              // Location OFF Warning Banner
              if (!bluetoothService.isLocationEnabled)
                Container(
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.red),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Location (GPS) is OFF! BLE scanning requires Location to be enabled.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 12),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => openAppSettings(),
                        child: const Text('Turn On', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // Animated Pulse Radar Scan Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (bluetoothService.isScanning)
                            AnimatedBuilder(
                              animation: _radarController,
                              builder: (context, child) {
                                return Container(
                                  width: 70 + (_radarController.value * 30),
                                  height: 70 + (_radarController.value * 30),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor.withValues(alpha: 0.15 * (1 - _radarController.value)),
                                  ),
                                );
                              },
                            ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withValues(alpha: 0.15),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Icon(
                              bluetoothService.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_connected,
                              size: 32,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bluetoothService.isScanning
                          ? 'Finding User..'
                          : discovered.isEmpty
                              ? 'No nearby devices found'
                              : 'Found ${discovered.length} nearby device(s)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<List<String>>(
                      future: Future.wait([
                        ProfileService.getDeviceId(),
                        ProfileService.getBluetoothMacAddress(),
                      ]),
                      builder: (context, snapshot) {
                        final myId = snapshot.data?[0] ?? 'Loading...';
                        final myMac = snapshot.data?[1] ?? 'Loading...';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Your Device ID: $myId',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.primaryColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bluetooth Address: $myMac',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.hintColor),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Device List
              Expanded(
                child: discovered.isEmpty
                    ? _buildEmptyState(context, bluetoothService)
                    : ListView.builder(
                        itemCount: discovered.length,
                        itemBuilder: (context, index) {
                          final item = discovered[index];
                          return DiscoveredDeviceTile(
                            item: item,
                            onTap: () {
                              bluetoothService.stopScan();
                              Navigator.pushNamed(
                                context,
                                '/payment_input',
                                arguments: {'device': item.device, 'recipientName': item.name},
                              );
                            },
                          ).animate(delay: (100 * index).ms).fade(duration: 500.ms).slideX(begin: 0.1, end: 0);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, OffpayBluetoothService service) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 56,
            color: theme.brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No nearby Bluetooth devices found.\nMake sure nearby receivers have Bluetooth enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => service.startScan(),
          ),
        ],
      ),
    ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class DiscoveredDeviceTile extends StatelessWidget {
  final DiscoveredDevice item;
  final VoidCallback onTap;

  const DiscoveredDeviceTile({
    required this.item,
    required this.onTap,
    super.key,
  });

  Color _getSignalColor(int level) {
    switch (level) {
      case 3:
        return Colors.green;
      case 2:
        return Colors.amber;
      case 1:
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color;
    final isOffpay = item.isOffpayUser;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isOffpay ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOffpay
            ? const BorderSide(color: Colors.indigo, width: 1.5)
            : BorderSide.none,
      ),
      color: isOffpay ? Colors.indigo.withValues(alpha: 0.04) : cardColor,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Icon Stack
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOffpay
                        ? Colors.indigo.withValues(alpha: 0.15)
                        : theme.primaryColor.withValues(alpha: 0.1),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    isOffpay ? Icons.verified_user : Icons.phone_android,
                    color: isOffpay ? Colors.indigo : theme.primaryColor,
                    size: 24,
                  ),
                ),
                CircleAvatar(
                  radius: 6,
                  backgroundColor: _getSignalColor(item.signalLevel),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Middle Column: Badges, Device ID, Subtitles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isOffpay) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 11, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'OFFPAY User',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getSignalColor(item.signalLevel).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.rssi} dBm',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getSignalColor(item.signalLevel),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.near_me, size: 12, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(
                        'Dist: ${item.estimatedDistance}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: theme.hintColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Connect Action Button
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}