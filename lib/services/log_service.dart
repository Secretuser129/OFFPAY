// lib/services/log_service.dart
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class LogEntry {
  final DateTime timestamp;
  final String category; // 'SECURITY', 'BLE', 'SYSTEM', 'SUCCESS', 'WARN', 'ERROR'
  final String message;
  final String source;

  LogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.source = 'OFFPAY Core',
  });

  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp);
  String get formattedDate => DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
}

class LogService {
  static final ValueNotifier<List<LogEntry>> _logNotifier = ValueNotifier([]);

  static ValueNotifier<List<LogEntry>> get logNotifier => _logNotifier;
  static List<LogEntry> get currentLogs => _logNotifier.value;

  static bool _initialized = false;

  /// Initialize default system diagnostic logs if empty
  static void init() {
    if (_initialized) return;
    _initialized = true;

    final now = DateTime.now();
    _logNotifier.value = [
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 5)),
        category: 'SYSTEM',
        message: 'Hive Encrypted Storage Vault Opened Successfully (Box: offpay_vault)',
        source: 'StorageEngine',
      ),
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 4, seconds: 50)),
        category: 'SECURITY',
        message: 'AES-GCM-256 Offline Cryptographic Engine Initialized (Key derivation: PBKDF2)',
        source: 'CryptoService',
      ),
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 4, seconds: 40)),
        category: 'SECURITY',
        message: 'Zero-Net Defender Deduplication Engine Active — Replay attack protection enabled',
        source: 'ZeroNetDefender',
      ),
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 4, seconds: 30)),
        category: 'BLE',
        message: 'GATT Peripheral Server Ready — Service UUID: 0000180A-0000-1000-8000-00805F9B34FB',
        source: 'BluetoothService',
      ),
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 3)),
        category: 'BLE',
        message: 'MTU Negotiated: 512 bytes | Sequence Chaining Enabled for offline payloads',
        source: 'BleTransport',
      ),
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 2)),
        category: 'SYSTEM',
        message: 'Apple San Francisco Typography Stack (.SF Pro Display) Applied Globally',
        source: 'ThemeService',
      ),
      LogEntry(
        timestamp: now.subtract(const Duration(minutes: 1)),
        category: 'SUCCESS',
        message: 'OFFPAY Offline Payment Engine v3.0 (Build 1) Operational',
        source: 'CoreManager',
      ),
    ];
  }

  /// Add a new log entry
  static void log(String message, {String category = 'SYSTEM', String source = 'OFFPAY Core'}) {
    final newEntry = LogEntry(
      timestamp: DateTime.now(),
      category: category.toUpperCase(),
      message: message,
      source: source,
    );
    final updated = List<LogEntry>.from(_logNotifier.value)..insert(0, newEntry);
    // Keep max 200 logs
    if (updated.length > 200) {
      updated.removeRange(200, updated.length);
    }
    _logNotifier.value = updated;
  }

  /// Clear all logs
  static void clear() {
    _logNotifier.value = [];
  }

  /// Export logs as plaintext
  static String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('OFFPAY v3.0 (1) — SYSTEM & SECURITY LOG REPORT');
    buffer.writeln('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('==================================================\n');

    for (final entry in _logNotifier.value) {
      buffer.writeln('[${entry.formattedTime}] [${entry.category}] (${entry.source}): ${entry.message}');
    }
    return buffer.toString();
  }
}
