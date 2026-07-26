// lib/services/bluetooth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'handshake_crypto_service.dart';
import 'profile_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;

/// Guid constants for OFFPAY service and characteristic
final fb.Guid OFFPAY_SERVICE_UUID = fb.Guid("0000180A-0000-1000-8000-00805F9B34FB");
final fb.Guid OFFPAY_CHAR_UUID = fb.Guid("00002A29-0000-1000-8000-00805F9B34FB");

class DiscoveredDevice {
  final fb.BluetoothDevice device;
  int rssi;
  DateTime lastSeen;
  fb.AdvertisementData advertisementData;
  fb.BluetoothConnectionState connectionState;

  DiscoveredDevice({
    required this.device,
    required this.rssi,
    required this.lastSeen,
    required this.advertisementData,
    this.connectionState = fb.BluetoothConnectionState.disconnected,
  });

  String get id => device.remoteId.str;
  String get bluetoothAddress => device.remoteId.str;

  String get name {
    if (advertisementData.serviceData.containsKey(OFFPAY_SERVICE_UUID)) {
      try {
        final decodedName = utf8.decode(advertisementData.serviceData[OFFPAY_SERVICE_UUID]!);
        if (decodedName.isNotEmpty) return decodedName;
      } catch (_) {}
    }
    if (device.platformName.isNotEmpty) return device.platformName;
    if (advertisementData.advName.isNotEmpty) return advertisementData.advName;
    return id;
  }

  /// Check if device is an authentic OFFPAY broadcast device
  bool get isOffpayUser {
    final normName = name.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final normId = id.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final hasUuid = advertisementData.serviceUuids.contains(OFFPAY_SERVICE_UUID);
    return normName.contains('OFFPAY') || normId.contains('OFFPAY') || hasUuid;
  }

  /// Categorize signal strength for user display
  String get signalQuality {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -80) return 'Medium';
    return 'Weak';
  }

  /// Estimated distance category based on BLE path loss model
  String get estimatedDistance {
    if (rssi >= -55) return '< 1m (Immediate)';
    if (rssi >= -75) return '1 - 3m (Near)';
    return '> 3m (Far)';
  }

  /// Return signal level 1..3 for UI icon/meter
  int get signalLevel {
    if (rssi >= -60) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }
}

class OffpayBluetoothService with ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.offpay/bluetooth');

  bool _isScanning = false;
  bool _isInPaymentFlow = false;
  fb.BluetoothAdapterState _adapterState = fb.BluetoothAdapterState.unknown;
  final Map<String, DiscoveredDevice> _deviceMap = {};

  StreamSubscription<List<fb.ScanResult>>? _scanResultsSubscription;
  StreamSubscription<fb.BluetoothAdapterState>? _adapterStateSubscription;

  fb.BluetoothDevice? _connectedDevice;

  // Realtime Incoming Payment Stream & BLE Receiver Broadcast State
  bool _isListeningForIncoming = false;
  bool _isBroadcastingReceiver = false;
  final StreamController<Map<String, dynamic>> _incomingPaymentController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Side-by-Side Proximity Detection Stream
  final StreamController<DiscoveredDevice> _proximityController =
      StreamController<DiscoveredDevice>.broadcast();

  OffpayBluetoothService() {
    _initAdapterStateListener();
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPaymentReceived') {
        final String payload = call.arguments as String;
        debugPrint('Native GATT Server received payload: $payload');
        try {
          final receiverId = await ProfileService.getDeviceId();
          final response = HandshakeCryptoService.createReceiverResponse(
            step1Packet: payload,
            receiverDeviceId: receiverId,
          );
          
          if (response != null && _isListeningForIncoming) {
            final senderData = response['senderData'] as Map<String, dynamic>;
            _incomingPaymentController.add({
              'amount': (senderData['amt'] as num).toDouble(),
              'senderId': senderData['sId'],
              'senderName': senderData['sName'],
              'timestamp': senderData['ts'],
              'transactionId': 'TXN-${senderData['nonce']}',
              'signature': payload.split(':').last,
            });
            debugPrint('Successfully verified incoming GATT payment!');
          } else {
            debugPrint('Failed to verify incoming GATT payment payload.');
          }
        } catch (e) {
          debugPrint('Error processing incoming GATT payload: $e');
        }
      }
    });
  }

  // --- Public Getters ---
  bool get isScanning => _isScanning;
  bool get isInPaymentFlow => _isInPaymentFlow;
  fb.BluetoothAdapterState get adapterState => _adapterState;
  bool get isBluetoothOn => _adapterState == fb.BluetoothAdapterState.on;
  bool get isListeningForIncoming => _isListeningForIncoming;
  bool get isBroadcastingReceiver => _isBroadcastingReceiver;
  fb.BluetoothDevice? get connectedDevice => _connectedDevice;

  void setInPaymentFlow(bool value) {
    if (_isInPaymentFlow != value) {
      _isInPaymentFlow = value;
      notifyListeners();
    }
  }

  Stream<Map<String, dynamic>> get onIncomingPayment => _incomingPaymentController.stream;
  Stream<DiscoveredDevice> get onProximityDeviceDetected => _proximityController.stream;

  /// Returns ALL discovered devices sorted with OFFPAY devices first, then by signal strength (RSSI)
  List<DiscoveredDevice> get discoveredDevices {
    var list = _deviceMap.values.toList();
    list.sort((a, b) {
      if (a.isOffpayUser && !b.isOffpayUser) return -1;
      if (!a.isOffpayUser && b.isOffpayUser) return 1;
      return b.rssi.compareTo(a.rssi);
    });
    return List.unmodifiable(list);
  }

  /// Returns list of fb.BluetoothDevice for backward compatibility
  List<fb.BluetoothDevice> get devices {
    return List.unmodifiable(discoveredDevices.map((d) => d.device));
  }

  // -------------------------
  // Real-time Adapter Listener
  // -------------------------
  void _initAdapterStateListener() {
    _adapterStateSubscription = fb.FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      debugPrint('Real-time Bluetooth Adapter State: $state');
      notifyListeners();
    });
  }

  // -------------------------
  // Permission Helper
  // -------------------------
  Future<bool> requestBluetoothPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
          Permission.location,
        ].request();

        bool isLocationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
        bool isBleScanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;

        // On Android 12+, bluetoothScan is required. On Android 11, locationWhenInUse is required.
        // We will consider it essential if EITHER of the core scanning permissions is granted.
        bool essentialGranted = (isLocationGranted || isBleScanGranted);
        
        return essentialGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return true;
    }
  }

  // -------------------------
  // Enable Bluetooth Radio
  // -------------------------
  Future<bool> enableBluetoothRadio() async {
    final granted = await requestBluetoothPermissions();
    if (!granted) {
      debugPrint('Bluetooth permissions not granted.');
      return false;
    }

    try {
      final state = await fb.FlutterBluePlus.adapterState.first;
      if (state == fb.BluetoothAdapterState.on) {
        return true;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        await fb.FlutterBluePlus.turnOn();
        final newState = await fb.FlutterBluePlus.adapterState
            .firstWhere((s) => s == fb.BluetoothAdapterState.on)
            .timeout(const Duration(seconds: 5), onTimeout: () => fb.BluetoothAdapterState.off);
        return newState == fb.BluetoothAdapterState.on;
      }
    } catch (e) {
      debugPrint('Error enabling Bluetooth radio: $e');
    }
    return false;
  }

  // -------------------------
  // Location Service Check (Required for BLE scanning on Android 10/11)
  // -------------------------
  bool _isLocationEnabled = true;
  bool get isLocationEnabled => _isLocationEnabled;

  Future<bool> checkLocationEnabled() async {
    try {
      final status = await Permission.locationWhenInUse.serviceStatus;
      _isLocationEnabled = status.isEnabled;
      notifyListeners();
      return _isLocationEnabled;
    } catch (e) {
      debugPrint('Location check error: $e');
      return true; // Assume enabled if check fails
    }
  }

  // -------------------------
  // Real-time Unfiltered Scanning (Guaranteed Android 10/11/12/14 Compatibility)
  // -------------------------
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (_isScanning) {
      // Force stop previous scan so we can restart
      await stopScan();
    }

    final isRadioOn = await enableBluetoothRadio();
    if (!isRadioOn) {
      debugPrint('Bluetooth radio not enabled. Cannot start scan.');
      return;
    }

    // Check location service
    await checkLocationEnabled();
    if (!_isLocationEnabled) {
      debugPrint('Location service is OFF. BLE scanning will return 0 results on Android 10/11.');
    }

    _isScanning = true;
    _deviceMap.clear();
    notifyListeners();

    _scanResultsSubscription?.cancel();
    _scanResultsSubscription = fb.FlutterBluePlus.scanResults.listen(
      (results) {
        final now = DateTime.now();
        for (fb.ScanResult r in results) {
          final deviceId = r.device.remoteId.str;
          final discovered = DiscoveredDevice(
            device: r.device,
            rssi: r.rssi,
            lastSeen: now,
            advertisementData: r.advertisementData,
          );
          _deviceMap[deviceId] = discovered;

          // Emit proximity pop-up trigger if device is close (side-by-side RSSI >= -65)
          if (r.rssi >= -65) {
            _proximityController.add(discovered);
          }
        }
        notifyListeners();
      },
      onError: (e) => debugPrint('Scan Stream Error: $e'),
    );

    try {
      await fb.FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: fb.AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint('startScan error: $e');
    }

    // Scan finished (timeout reached) — reset scanning state
    _isScanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    try {
      await fb.FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('stopScan error: $e');
    }
    _isScanning = false;
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    notifyListeners();
  }

  // -------------------------
  // Paired Devices
  // -------------------------
  Future<List<fb.BluetoothDevice>> getPairedDevices() async {
    try {
      final paired = await fb.FlutterBluePlus.bondedDevices;
      return paired;
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  // -------------------------
  // Real-time Connect & Transfer (GATT 133 Retry Counter Countermeasure)
  // -------------------------


  /// Step 1: Connect to the device separately
  Future<bool> connectToDevice(fb.BluetoothDevice device) async {
    final isRadioOn = await enableBluetoothRadio();
    if (!isRadioOn) return false;

    await stopScan();
    final deviceId = device.remoteId.str;
    
    // Check if already connected
    try {
      final current = await device.connectionState.first;
      if (current == fb.BluetoothConnectionState.connected) {
        _connectedDevice = device;
        return true;
      }
    } catch (_) {}

    const int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('GATT Connection Attempt $attempt of $maxRetries for $deviceId');
        await device.connect(autoConnect: false, license: fb.License.nonprofit);

        final connectedState = await device.connectionState
            .firstWhere((s) => s == fb.BluetoothConnectionState.connected || s == fb.BluetoothConnectionState.disconnected)
            .timeout(const Duration(seconds: 3), onTimeout: () => fb.BluetoothConnectionState.disconnected);

        if (connectedState == fb.BluetoothConnectionState.connected) {
          _connectedDevice = device;
          if (_deviceMap.containsKey(deviceId)) {
            _deviceMap[deviceId]!.connectionState = fb.BluetoothConnectionState.connected;
            notifyListeners();
          }
          debugPrint('GATT Connected successfully on attempt $attempt: $deviceId');
          return true;
        } else {
          try { await device.disconnect(); } catch (_) {}
        }
      } catch (e) {
        debugPrint('GATT Attempt $attempt error: $e');
        try { await device.disconnect(); } catch (_) {}
      }
      if (attempt < maxRetries) await Future.delayed(Duration(milliseconds: 300 * attempt));
    }
    return false;
  }

  /// Step 2: Transfer to an already connected device
  Future<String?> transferToConnectedDevice(fb.BluetoothDevice device, double amount) async {
    try {
      final current = await device.connectionState.first;
      if (current != fb.BluetoothConnectionState.connected) {
        debugPrint('Cannot transfer, device is disconnected.');
        return null;
      }

      final List<fb.BluetoothService> services = await device.discoverServices().timeout(
        const Duration(seconds: 4),
        onTimeout: () => [],
      );

      fb.BluetoothService? offpayService;
      try {
        offpayService = services.firstWhere((s) => s.uuid == OFFPAY_SERVICE_UUID);
      } catch (_) {
        offpayService = null;
      }

      if (offpayService != null) {
        fb.BluetoothCharacteristic? writeChar;
        try {
          writeChar = offpayService.characteristics.firstWhere((c) => c.uuid == OFFPAY_CHAR_UUID);
        } catch (_) {
          writeChar = null;
        }

        if (writeChar != null) {
          final senderId = await ProfileService.getDeviceId();
          final senderName = await ProfileService.getUserName();
          final handshake = HandshakeCryptoService.createSenderHandshake(
            senderDeviceId: senderId,
            senderName: senderName,
            amount: amount,
          );
          final String payload = handshake['packet']!;
          final List<int> payloadBytes = utf8.encode(payload);

          final canWrite = writeChar.properties.write;
          final canWriteWithoutResponse = writeChar.properties.writeWithoutResponse;

          if (canWrite || canWriteWithoutResponse) {
            await writeChar.write(payloadBytes, withoutResponse: !canWrite);
            debugPrint('Wrote secure GATT payment payload to ${device.remoteId.str}: $payload');
            
            try { await device.disconnect(); } catch (_) {}
            
            return 'TXN-${handshake['nonce']}';
          }
        }
      }
    } catch (e, st) {
      debugPrint('transferToConnectedDevice error: $e\n$st');
    }

    try { await device.disconnect(); } catch (_) {}
    _connectedDevice = null;
    return null;
  }

  // -------------------------
  // Receiver Real-time Listener & BLE Advertising Broadcast
  // -------------------------
  Future<void> startListeningForPayments({String? deviceId, String? userName}) async {
    _isListeningForIncoming = true;
    _isBroadcastingReceiver = true;
    notifyListeners();

    // Ensure Bluetooth is ON and permissions are granted before advertising
    final isRadioOn = await enableBluetoothRadio();
    if (!isRadioOn) {
      debugPrint('BLE Advertising: Bluetooth radio not enabled, cannot advertise.');
      return;
    }

    try {
      // Use the user's actual Bluetooth name (e.g., "Rahul OFFPAY")
      // The native side truncates to max 8 chars for Android 10/11 compatibility
      final nameStr = userName ?? await ProfileService.getBluetoothName();
      await _channel.invokeMethod('startAdvertising', {
        'name': nameStr,
        'serviceUuid': OFFPAY_SERVICE_UUID.str,
      });
      debugPrint('BLE Advertising SUCCESS: Broadcasting as "$nameStr" (deviceId: $deviceId)');
    } catch (e) {
      debugPrint('BLE Advertising FAILED: $e');
    }
  }

  /// Start background advertising so device is discoverable on Home Screen & anywhere in app
  Future<void> startBackgroundAdvertising() async {
    final isRadioOn = await enableBluetoothRadio();
    if (!isRadioOn) return;

    try {
      // Use the user's actual Bluetooth name so senders can see who they're paying
      final advName = await ProfileService.getBluetoothName();
      await _channel.invokeMethod('startAdvertising', {
        'name': advName,
        'serviceUuid': OFFPAY_SERVICE_UUID.str,
      });
      debugPrint('Background OFFPAY advertising active: $advName');
    } catch (e) {
      debugPrint('Background advertising error: $e');
    }
  }

  Future<void> stopListeningForPayments() async {
    _isListeningForIncoming = false;
    _isBroadcastingReceiver = false;
    try {
      await _channel.invokeMethod('stopAdvertising');
    } catch (_) {}
    notifyListeners();
    debugPrint('Stopped BLE Receiver Advertising mode.');
  }

  /// Step 2 Power-Cycle: Reset the Android Bluetooth stack if overlapping scans or GATT stall
  Future<void> powerCycleBluetooth() async {
    try {
      debugPrint('Executing Bluetooth stack power-cycle reset...');
      await stopScan();
      if (defaultTargetPlatform == TargetPlatform.android) {
        // ignore: deprecated_member_use
        await fb.FlutterBluePlus.turnOff();
        await Future.delayed(const Duration(milliseconds: 800));
        await fb.FlutterBluePlus.turnOn();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('powerCycleBluetooth error: $e');
    }
  }

  /// Simulate receiving an incoming Bluetooth payment for stage/judge presentation demos
  void simulateIncomingPayment(double amount, String senderId) {
    if (!_isListeningForIncoming) return;

    _incomingPaymentController.add({
      'amount': amount,
      'senderId': senderId,
      'timestamp': DateTime.now(),
    });

    debugPrint('Simulated incoming Bluetooth payment received: ₹$amount from $senderId');
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _incomingPaymentController.close();
    _proximityController.close();
    super.dispose();
  }
}