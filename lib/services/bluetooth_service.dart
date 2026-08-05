// lib/services/bluetooth_service.dart
//
// ANDROID MANIFEST / GRADLE CHECKLIST (required alongside this file — none of
// the Dart-side fixes below matter if these are missing):
//   android/app/build.gradle(.kts): minSdkVersion 26 (Android 8.0)
//   AndroidManifest.xml:
//     <uses-permission android:name="android.permission.BLUETOOTH"
//         android:maxSdkVersion="30" />
//     <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
//         android:maxSdkVersion="30" />
//     <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
//         android:maxSdkVersion="30" />   <!-- required for BLE scan on 8-11 -->
//     <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
//         android:usesPermissionFlags="neverForLocation" />  <!-- 12+, omit the
//         flag if you actually derive physical location from scan results -->
//     <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
//     <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
//     <uses-feature android:name="android.hardware.bluetooth_le"
//         android:required="true" />
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'handshake_crypto_service.dart';
import 'profile_service.dart';
import 'sequence_chaining_service.dart';
import 'log_service.dart';
import 'notification_service.dart';
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

  String get _rawName {
    // 1. Check all serviceData entries (supports full UUID and short 16-bit 180A)
    for (final entry in advertisementData.serviceData.entries) {
      final keyStr = entry.key.str.toLowerCase();
      if (keyStr == OFFPAY_SERVICE_UUID.str.toLowerCase() || keyStr.contains('180a')) {
        try {
          final decodedName = utf8.decode(entry.value);
          if (decodedName.trim().isNotEmpty) return decodedName.trim();
        } catch (_) {}
      }
    }
    // 2. Check advertisement advName
    if (advertisementData.advName.trim().isNotEmpty) return advertisementData.advName.trim();
    // 3. Check platformName
    if (device.platformName.trim().isNotEmpty) return device.platformName.trim();
    return '';
  }

  String get name {
    final raw = _rawName;
    if (raw.isNotEmpty) return raw;
    if (isOffpayUser) {
      return 'OFFPAY USER (${id.length >= 8 ? id.substring(id.length - 8) : id})';
    }
    return 'Bluetooth Device (${id.length >= 8 ? id.substring(id.length - 8) : id})';
  }

  /// Check if device is an authentic OFFPAY broadcast device (checks multiple types!)
  bool get isOffpayUser {
    final normName = _rawName.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final normId = id.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final hasUuid = advertisementData.serviceUuids.any((u) {
      final uStr = u.str.toLowerCase();
      return uStr == OFFPAY_SERVICE_UUID.str.toLowerCase() || uStr.contains('180a');
    });
    final hasServiceData = advertisementData.serviceData.keys.any((u) {
      final uStr = u.str.toLowerCase();
      return uStr == OFFPAY_SERVICE_UUID.str.toLowerCase() || uStr.contains('180a');
    });
    return normName.contains('OFFPAY') || normId.contains('OFFPAY') || hasUuid || hasServiceData;
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

  // Guards against overlapping connect() calls to the same device — issuing a
  // second connect() while one is already in flight is one of the most common
  // triggers of GATT_ERROR 133 on Android 8/9.
  final Set<String> _connectingDeviceIds = {};
  StreamSubscription<fb.BluetoothConnectionState>? _connectionStateSub;

  // Realtime Incoming Payment Stream & BLE Receiver Broadcast State
  bool _isListeningForIncoming = false;
  bool _isBroadcastingReceiver = false;
  final StreamController<Map<String, dynamic>> _incomingPaymentController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Side-by-Side Proximity Detection Stream
  final StreamController<DiscoveredDevice> _proximityController =
      StreamController<DiscoveredDevice>.broadcast();

  // Pairing code stream for receiver
  final StreamController<String> _incomingPairingCodeController =
      StreamController<String>.broadcast();

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
            final incomingSeq = (senderData['seq'] as num?)?.toInt() ?? 1;
            final prevHash = (senderData['prevHash'] as String?) ?? 'GENESIS_OFFPAY_CHAIN_HASH_00000000';
            final amount = (senderData['amt'] as num).toDouble();
            final senderId = senderData['sId'] as String;
            final nonce = senderData['nonce'] as String;
            final ts = (senderData['ts'] as num).toInt();

            final seqCheck = await SequenceChainingService.verifyAndRecordIncomingTransaction(
              senderId: senderId,
              incomingSeq: incomingSeq,
              nonce: nonce,
              prevHash: prevHash,
              amount: amount,
              timestamp: ts,
            );

            if (!seqCheck.isValid) {
              debugPrint('REJECTED INCOMING TRANSACTION: ${seqCheck.reason}');
              return;
            }

            final String senderDisplayName =
                (senderData['sName']?.toString().isNotEmpty == true)
                    ? senderData['sName']
                    : senderId;
            _incomingPaymentController.add({
              'amount': amount,
              'senderId': senderId,
              'senderName': senderDisplayName,
              'timestamp': ts,
              'transactionId': 'TXN-$nonce',
              'signature': payload.split(':').last,
            });
            await NotificationService.showPaymentReceivedNotification(
              amount: amount,
              senderName: senderDisplayName,
              transactionId: 'TXN-$nonce',
            );
            debugPrint('Successfully verified incoming GATT payment with sequence chaining!');
          } else {
            debugPrint('Failed to verify incoming GATT payment payload.');
          }
        } catch (e) {
          debugPrint('Error processing incoming GATT payload: $e');
        }
      } else if (call.method == 'onGattConnected') {
        final deviceId = call.arguments['deviceId'] as String;
        debugPrint('Native GATT Server received connection from: $deviceId');
        try {
          final myDeviceId = await ProfileService.getDeviceId();
          // generatePairingCode uses deterministic sort, so order of IDs doesn't matter
          final pairingCode = generatePairingCode(myDeviceId, deviceId);
          debugPrint('Receiver generated pairing code: $pairingCode');
          _incomingPairingCodeController.add(pairingCode);
        } catch (e) {
          debugPrint('Error generating pairing code on receiver side: $e');
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
  Stream<String> get incomingPairingCodeStream => _incomingPairingCodeController.stream;

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
        // IMPORTANT: Permission.location (background location) is deliberately
        // NOT requested here. On Android 11+, bundling a background-location
        // request together with foreground permissions in one request() call
        // causes the OS to silently refuse to grant it — Google requires
        // background location to be requested on its own, after the
        // foreground permission is already granted. We don't need it for BLE
        // scanning anyway, so it's dropped rather than fixed.
        //
        // bluetoothScan/bluetoothConnect/bluetoothAdvertise only exist on
        // Android 12+ (API 31+); permission_handler auto-resolves them to
        // "granted" on older OS versions, so requesting them unconditionally
        // is safe all the way back to Android 8.
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.locationWhenInUse,
        ].request();

        bool isLocationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
        bool isBleScanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
        bool isBleConnectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;

        // Android 8-11 (API 26-30): scanning AND connecting only need
        // locationWhenInUse — there's no separate runtime "connect" permission.
        // Android 12+ (API 31+): scanning needs bluetoothScan, and — critically —
        // device.connect() will fail on its own with a permission error unless
        // bluetoothConnect is ALSO granted. Treating scan-only as "good enough"
        // (the previous behavior) let the code proceed straight into a connect
        // attempt that was doomed to fail with a confusing native error.
        bool essentialGranted = isLocationGranted || (isBleScanGranted && isBleConnectGranted);

        if (!essentialGranted) {
          LogService.log(
            'Bluetooth permissions incomplete — location: $isLocationGranted, scan: $isBleScanGranted, connect: $isBleConnectGranted',
            category: 'WARN',
            source: 'BluetoothService',
          );
        }

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
  // Location Service Check (required by flutter_blue_plus on ALL Android
  // versions by default — not just 8-11 — unless neverForLocation is set)
  // -------------------------
  bool _isLocationEnabled = true;
  bool get isLocationEnabled => _isLocationEnabled;

  Future<bool> checkLocationEnabled() async {
    try {
      final status = await Permission.locationWhenInUse.serviceStatus;
      _isLocationEnabled = status.isEnabled;
      if (!_isLocationEnabled) {
        LogService.log('Location service is DISABLED on device. Android BLE scans require Location to be ON.', category: 'ERROR', source: 'LocationService');
      }
      notifyListeners();
      return _isLocationEnabled;
    } catch (e) {
      debugPrint('Location check error: $e');
      return true; // Assume enabled if check fails
    }
  }

  // -------------------------
  // Real-time Unfiltered Scanning (Guaranteed Android 8/10/11/12/13/14 Compatibility)
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

    // Check location service. This is NOT just an Android 8-11 requirement —
    // flutter_blue_plus defaults to androidCheckLocationServices: true
    // internally on EVERY Android version (including 12+), and will throw if
    // Location Services is off unless you've both added
    // `android:usesPermissionFlags="neverForLocation"` to the BLUETOOTH_SCAN
    // entry in AndroidManifest.xml AND passed androidCheckLocationServices:
    // false to startScan(). Without both of those, a scanning phone on
    // Android 14 with Location Services toggled off will silently find
    // nothing at all — not just "can't find one specific device" — because
    // the scan itself never actually runs; the old code let that exception
    // get swallowed by the generic catch below with no visible cause.
    await checkLocationEnabled();
    if (!_isLocationEnabled) {
      debugPrint('Location service is OFF — aborting scan before it silently fails.');
      LogService.log(
        'Location service is OFF. Scan aborted. Enable Location Services on this '
        'device, or configure BLUETOOTH_SCAN with neverForLocation + '
        'androidCheckLocationServices:false if you want scanning to work with it off.',
        category: 'ERROR',
        source: 'BluetoothService',
      );
      notifyListeners();
      return; // fail fast instead of calling startScan() and getting 0 results
    }

    _isScanning = true;
    LogService.log('Started BLE Nearby Peripheral Scan (${timeout.inSeconds}s sweep, dual-mode)', category: 'BLE', source: 'BluetoothService');
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
        if (results.isNotEmpty) {
          notifyListeners();
        }
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
    LogService.log('BLE Scan Completed — Found ${_deviceMap.length} nearby device(s)', category: 'BLE', source: 'BluetoothService');
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
  // Real-time Connect & Transfer (GATT 133 Retry + Pairing Code for Android 8+)
  // -------------------------
  /// Generate a deterministic 6-digit pairing code from both device IDs
  /// so both sender and receiver can verify the same code on screen.
  String generatePairingCode(String myDeviceId, String remoteDeviceId) {
    final sorted = [myDeviceId, remoteDeviceId]..sort();
    final combined = '${sorted[0]}:${sorted[1]}:OFFPAY_PAIR_2026';
    final hash = utf8.encode(combined);
    int code = 0;
    for (final b in hash) {
      code = (code * 31 + b) & 0x7FFFFFFF;
    }
    return (100000 + (code % 900000)).toString();
  }

  /// Step 1: Connect to the device (Stable for Android 8/9/10/11/12/13/14/15/16)
  ///
  /// Android's BLE stack frequently surfaces GATT_ERROR 133
  /// (ANDROID_SPECIFIC_ERROR) on Oreo/Pie devices especially, but it can show
  /// up on any version. The three things that matter most for avoiding it:
  ///   1. never let two connect() calls to the same device overlap
  ///   2. give the radio time to settle after scanning/disconnecting before
  ///      the next connect attempt (and before the first GATT op after connect)
  ///   3. back off with increasing delay between retries, not a fixed one
  ///
  /// Returns pairing code on success, null on failure
  Future<String?> connectToDeviceWithPairing(fb.BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    // Reentrancy guard: a second connect() while one is already running is a
    // common way to strand the native GATT client in a bad state on Android 8/9.
    if (_connectingDeviceIds.contains(deviceId)) {
      debugPrint('Connect already in progress for $deviceId, ignoring duplicate call.');
      return null;
    }
    _connectingDeviceIds.add(deviceId);

    try {
      final isRadioOn = await enableBluetoothRadio();
      if (!isRadioOn) return null;

      await stopScan();
      // Allow the Android BLE radio to transition cleanly out of scan mode.
      // 500ms is the bare minimum quoted anywhere for this; Oreo/Pie devices
      // are noticeably more reliable around ~800ms.
      await Future.delayed(const Duration(milliseconds: 800));

      final myId = await ProfileService.getDeviceId();
      final pairingCode = generatePairingCode(myId, deviceId);

      // Check if already connected in Android GATT stack
      try {
        final current = await device.connectionState.first;
        if (current == fb.BluetoothConnectionState.connected) {
          _connectedDevice = device;
          _watchConnectionState(device);
          if (_deviceMap.containsKey(deviceId)) {
            _deviceMap[deviceId]!.connectionState = fb.BluetoothConnectionState.connected;
            notifyListeners();
          }
          debugPrint('GATT already connected: $deviceId');
          return pairingCode;
        }
      } catch (_) {}

      // Force-close any stale native GATT client before trying fresh — if the
      // app thinks it's disconnected but Android's stack never fully released
      // the previous connection, the next connect() reproduces 133 immediately.
      try {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}

      const int maxRetries = 4;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          debugPrint('GATT Connection Attempt $attempt of $maxRetries for $deviceId');

          await device.connect(
            license: fb.License.nonprofit,
            autoConnect: false, // Always use direct fast connection
            timeout: const Duration(seconds: 15),
            mtu: null,
          );

          final current = await device.connectionState.first;
          if (current == fb.BluetoothConnectionState.connected) {
            _connectedDevice = device;
            _watchConnectionState(device);
            if (_deviceMap.containsKey(deviceId)) {
              _deviceMap[deviceId]!.connectionState = fb.BluetoothConnectionState.connected;
              notifyListeners();
            }

            // Let the connection settle before issuing any further GATT ops —
            // queuing bond/MTU requests immediately after onConnectionStateChange
            // fires is a well-documented 133 trigger on Android 8/9.
            await Future.delayed(const Duration(milliseconds: 400));

            if (defaultTargetPlatform == TargetPlatform.android) {
              try {
                // Only bond if not already bonded. Re-issuing createBond() on an
                // already-bonded device can trigger a duplicate pairing dialog
                // and leave the GATT client in a bad state on some OEM builds.
                // Bonding is best-effort here — the app has its own
                // application-level pairing code (see generatePairingCode), so
                // OS-level bonding must never block or fail the connection.
                final bondState = await device.bondState.first;
                if (bondState != fb.BluetoothBondState.bonded) {
                  await device.createBond().timeout(
                    const Duration(seconds: 8),
                    onTimeout: () {},
                  );
                }
              } catch (e) {
                debugPrint('Bond note (non-fatal): $e');
              }
              try {
                await device.requestMtu(512).timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => 512,
                );
              } catch (e) {
                debugPrint('MTU request note: $e');
              }
            }
            await Future.delayed(const Duration(milliseconds: 300));

            debugPrint('GATT Connected successfully on attempt $attempt: $deviceId');
            LogService.log('GATT Connected (attempt $attempt) to $deviceId — Pairing Code: $pairingCode', category: 'SUCCESS', source: 'BluetoothService');
            return pairingCode;
          }
        } catch (e) {
          debugPrint('GATT Attempt $attempt error: $e');
          LogService.log('GATT Attempt $attempt error for $deviceId: $e', category: 'WARN', source: 'BluetoothService');
          try {
            await device.disconnect();
          } catch (_) {}
          // Give the native GATT client time to fully close before retrying —
          // reconnecting too soon after a 133 usually reproduces it instantly.
          await Future.delayed(const Duration(milliseconds: 400));
        }
        if (attempt < maxRetries) {
          // Exponential backoff: 800ms, 1600ms, 3200ms...
          final backoff = Duration(milliseconds: 800 * (1 << (attempt - 1)));
          await Future.delayed(backoff);
        }
      }
      return null;
    } finally {
      _connectingDeviceIds.remove(deviceId);
    }
  }

  /// Watches a connected device's connectionState and reactively clears local
  /// state the moment it drops. Android 8/9 BLE stacks disconnect more readily
  /// than modern ones, and a stale `_connectedDevice` reference causes
  /// confusing bugs elsewhere in the payment flow if it isn't cleared as soon
  /// as the drop happens.
  void _watchConnectionState(fb.BluetoothDevice device) {
    _connectionStateSub?.cancel();
    final deviceId = device.remoteId.str;
    _connectionStateSub = device.connectionState.listen((state) {
      if (_deviceMap.containsKey(deviceId)) {
        _deviceMap[deviceId]!.connectionState = state;
      }
      if (state == fb.BluetoothConnectionState.disconnected) {
        if (_connectedDevice?.remoteId.str == deviceId) {
          _connectedDevice = null;
        }
        debugPrint('GATT disconnected: $deviceId');
      }
      notifyListeners();
    });
    device.cancelWhenDisconnected(_connectionStateSub!);
  }

  /// Legacy connect method (backward compatible)
  Future<bool> connectToDevice(fb.BluetoothDevice device) async {
    final result = await connectToDeviceWithPairing(device);
    return result != null;
  }

  /// Step 2: Transfer to an already connected device (Robust Service & Char discovery)
  Future<String?> transferToConnectedDevice(fb.BluetoothDevice device, double amount) async {
    try {
      final current = await device.connectionState.first;
      if (current != fb.BluetoothConnectionState.connected) {
        debugPrint('Cannot transfer, device is disconnected.');
        return null;
      }

      bool discoveryTimedOut = false;
      final List<fb.BluetoothService> services = await device.discoverServices().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          discoveryTimedOut = true;
          return <fb.BluetoothService>[];
        },
      );
      if (discoveryTimedOut) {
        debugPrint('discoverServices() timed out for ${device.remoteId.str}');
        LogService.log(
          'GATT service discovery timed out for ${device.remoteId.str} — link is likely unstable, not just missing services.',
          category: 'WARN',
          source: 'BluetoothService',
        );
      }

      fb.BluetoothService? offpayService;
      try {
        offpayService = services.firstWhere((s) {
          final uStr = s.serviceUuid.str.toLowerCase();
          return uStr == OFFPAY_SERVICE_UUID.str.toLowerCase() || uStr.contains('180a');
        });
      } catch (_) {
        offpayService = services.isNotEmpty ? services.first : null;
      }

      if (offpayService != null) {
        fb.BluetoothCharacteristic? writeChar;
        for (fb.BluetoothCharacteristic c in offpayService.characteristics) {
          final uStr = c.characteristicUuid.str.toLowerCase();
          if (uStr == OFFPAY_CHAR_UUID.str.toLowerCase() || uStr.contains('2a29')) {
            writeChar = c;
            break;
          }
        }
        if (writeChar == null && offpayService.characteristics.isNotEmpty) {
          writeChar = offpayService.characteristics.first;
        }

        if (writeChar == null) {
          debugPrint('No write characteristic found.');
          return null;
        }

        // Secure Handshake & Cryptographic Sequence Chaining
        final senderId = await ProfileService.getDeviceId();
        final senderName = await ProfileService.getBluetoothName();
        final seq = await SequenceChainingService.getNextSequence(device.remoteId.str);
        final prevHash = await SequenceChainingService.getLastHash(device.remoteId.str);
        final handshake = HandshakeCryptoService.createSenderHandshake(
          senderDeviceId: senderId,
          senderName: senderName,
          amount: amount,
          seq: seq,
          prevHash: prevHash,
        );
        final String payload = handshake['packet']!;
        final List<int> payloadBytes = utf8.encode(payload);

        final canWrite = writeChar.properties.write;
        final canWriteWithoutResponse = writeChar.properties.writeWithoutResponse;

        if (canWrite || canWriteWithoutResponse) {
          await writeChar.write(payloadBytes, withoutResponse: !canWrite);
          debugPrint('Wrote secure GATT payment payload to ${device.remoteId.str}: $payload');
          LogService.log('Transmitted AES-256-CBC encrypted & HMAC-SHA256 signed payment packet (seq: $seq) over BLE GATT to ${device.remoteId.str}', category: 'SECURITY', source: 'HandshakeCrypto');
          
          // Allow 800ms for BLE link layer to complete air transmission without disconnecting
          await Future.delayed(const Duration(milliseconds: 800));
          
          return 'TXN-${handshake['nonce']}';
        }
      }
    } catch (e, st) {
      debugPrint('transferToConnectedDevice error: $e\n$st');
    }

    return null;
  }

  /// Verify BLUETOOTH_ADVERTISE is actually granted before invoking the
  /// native advertiser. On Android 12+, calling startAdvertising without it
  /// throws a native SecurityException that surfaces as an opaque platform
  /// exception — checking first gives a clear, actionable log instead.
  Future<bool> _isAdvertisePermissionGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await Permission.bluetoothAdvertise.isGranted;
    } catch (e) {
      debugPrint('Advertise permission check error: $e');
      return true; // don't block advertising on a check failure itself
    }
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

    if (!await _isAdvertisePermissionGranted()) {
      debugPrint('BLE Advertising: BLUETOOTH_ADVERTISE not granted, cannot advertise.');
      LogService.log(
        'BLUETOOTH_ADVERTISE permission missing — advertising cannot start on Android 12+.',
        category: 'ERROR',
        source: 'BluetoothService',
      );
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

    if (!await _isAdvertisePermissionGranted()) {
      debugPrint('Background advertising: BLUETOOTH_ADVERTISE not granted.');
      LogService.log(
        'BLUETOOTH_ADVERTISE permission missing — background advertising cannot start on Android 12+.',
        category: 'ERROR',
        source: 'BluetoothService',
      );
      return;
    }

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

  /// Simulate receiving an incoming Bluetooth payment for live presentation demos
  void simulateIncomingPayment(double amount, String senderId) {
    if (!_isListeningForIncoming) return;

    _incomingPaymentController.add({
      'amount': amount,
      'senderId': senderId,
      'timestamp': DateTime.now(),
    });

    NotificationService.showPaymentReceivedNotification(
      amount: amount,
      senderName: senderId,
    );

    debugPrint('Simulated incoming Bluetooth payment received: ₹$amount from $senderId');
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _connectionStateSub?.cancel();
    _incomingPaymentController.close();
    _proximityController.close();
    super.dispose();
  }
}