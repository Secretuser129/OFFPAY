import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/bluetooth_service.dart';
import '../services/profile_service.dart';
import '../services/firebase_service.dart';
import '../widgets/global_apple_dock.dart';

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
          bottomNavigationBar: const GlobalAppleDock(activeRoute: '/discovery'),
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
                                'Real Bluetooth MAC: $myMac',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primaryColor),
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
                            onTap: () async {
                              // Show connecting dialog with pairing code
                              _showPairingDialog(context, bluetoothService, item);
                            },
                          ).animate(delay: (100 * index).ms).fade(duration: 500.ms).slideX(begin: 0.1, end: 0);
                        },
                      ),
              ),
            ],
          ),
          // bottomNavigationBar removed for clean full-screen view
        );
      },
    );
  }

  void _showPairingDialog(BuildContext context, OffpayBluetoothService bluetoothService, DiscoveredDevice item) {
    bool isConnecting = true;
    String? pairingCode;
    bool connectionFailed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Start connection attempt
          if (isConnecting && pairingCode == null && !connectionFailed) {
            bluetoothService.connectToDeviceWithPairing(item.device).then((code) {
              if (!context.mounted) return;
              if (code != null) {
                setDialogState(() {
                  pairingCode = code;
                  isConnecting = false;
                });
              } else {
                setDialogState(() {
                  connectionFailed = true;
                  isConnecting = false;
                });
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  connectionFailed ? Icons.error_outline : Icons.bluetooth_connected,
                  color: connectionFailed ? Colors.red : Colors.indigo,
                ),
                const SizedBox(width: 10),
                Text(
                  connectionFailed
                      ? 'Connection Failed'
                      : isConnecting
                          ? 'Connecting...'
                          : 'Connected!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isConnecting) ...[
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(color: Colors.indigo),
                  const SizedBox(height: 16),
                  Text(
                    'Pairing with ${item.name}...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MAC: ${item.bluetoothAddress}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If a system pairing dialog appears,\ntap "Pair" to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ] else if (connectionFailed) ...[
                  const SizedBox(height: 10),
                  const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not connect to this device.\nMake sure it is nearby and has\nBluetooth enabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'OFFPAY Secure Pairing Code',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.indigo.shade300, width: 2),
                    ),
                    child: Text(
                      '${pairingCode?.substring(0, 3)} ${pairingCode?.substring(3)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verify this code matches on both phones before proceeding.',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected to: ${item.name}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              if (connectionFailed) ...[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: () {
                    setDialogState(() {
                      isConnecting = true;
                      connectionFailed = false;
                      pairingCode = null;
                    });
                  },
                ),
              ] else if (!isConnecting) ...[
                TextButton(
                  onPressed: () {
                    try { item.device.disconnect(); } catch (_) {}
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Code Matches — Pay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(
                      context,
                      '/payment_input',
                      arguments: {'device': item.device, 'recipientName': item.name},
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
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

class DiscoveredDeviceTile extends StatefulWidget {
  final DiscoveredDevice item;
  final VoidCallback onTap;

  const DiscoveredDeviceTile({
    required this.item,
    required this.onTap,
    super.key,
  });

  @override
  State<DiscoveredDeviceTile> createState() => _DiscoveredDeviceTileState();
}

class _DiscoveredDeviceTileState extends State<DiscoveredDeviceTile> {
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _fetchAvatar();
  }

  Future<void> _fetchAvatar() async {
    final targetId = widget.item.device.remoteId.str;
    final base64 = await FirebaseService.fetchUserPhotoBase64(targetId);
    if (base64 != null && mounted) {
      setState(() => _photoBase64 = base64);
    }
  }

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
    final isOffpay = widget.item.isOffpayUser;

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
                  child: _photoBase64 != null
                      ? CircleAvatar(
                          radius: 14,
                          backgroundImage: MemoryImage(base64Decode(_photoBase64!)),
                        )
                      : Icon(
                          isOffpay ? Icons.verified_user : Icons.phone_android,
                          color: isOffpay ? Colors.indigo : theme.primaryColor,
                          size: 24,
                        ),
                ),
                CircleAvatar(
                  radius: 6,
                  backgroundColor: _getSignalColor(widget.item.signalLevel),
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
                                'OFFPAY USER',
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
                          color: _getSignalColor(widget.item.signalLevel).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${widget.item.rssi} dBm',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getSignalColor(widget.item.signalLevel),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bluetooth, size: 12, color: isOffpay ? Colors.indigo : theme.hintColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Bluetooth MAC: ${widget.item.bluetoothAddress}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOffpay ? Colors.indigo.shade600 : theme.hintColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.near_me, size: 12, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(
                        'Dist: ${widget.item.estimatedDistance}',
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
              onPressed: widget.onTap,
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