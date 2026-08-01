import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to handle GZip compression for sync payloads and offline ledger packets.
/// Reduces transmission size by up to 75% for Bluetooth LE and Firebase Sync over poor networks.
class CompressedSyncService {
  static final GZipCodec _gzip = GZipCodec(level: 9); // Maximum compression level

  /// Compress a JSON or text payload into GZip bytes
  static List<int> compressPayload(String rawString) {
    try {
      final bytes = utf8.encode(rawString);
      return _gzip.encode(bytes);
    } catch (e) {
      debugPrint('Error compressing payload: $e');
      return utf8.encode(rawString);
    }
  }

  /// Decompress GZip bytes back to UTF-8 String
  static String decompressPayload(List<int> compressedBytes) {
    try {
      final decoded = _gzip.decode(compressedBytes);
      return utf8.decode(decoded);
    } catch (e) {
      debugPrint('Error decompressing payload: $e');
      return utf8.decode(compressedBytes);
    }
  }

  /// Compress a JSON object / String into a Base64-encoded GZip payload
  static String compressToBase64(String rawString) {
    try {
      final compressed = compressPayload(rawString);
      return 'GZ1:${base64Encode(compressed)}';
    } catch (e) {
      return rawString;
    }
  }

  /// Decompress from a Base64-encoded GZip string (supports 'GZ1:' prefix)
  static String decompressFromBase64(String encodedString) {
    try {
      if (!encodedString.startsWith('GZ1:')) {
        return encodedString;
      }
      final base64Part = encodedString.substring(4);
      final bytes = base64Decode(base64Part);
      return decompressPayload(bytes);
    } catch (e) {
      debugPrint('Error decompressing Base64 GZip payload: $e');
      return encodedString;
    }
  }

  /// Calculate compression savings ratio (percentage saved)
  static double calculateCompressionRatio(String original, String compressedBase64) {
    final origBytes = utf8.encode(original).length;
    final compBytes = compressedBase64.length;
    if (origBytes == 0) return 0.0;
    final ratio = (1.0 - (compBytes / origBytes)) * 100.0;
    return ratio.clamp(0.0, 100.0);
  }
}
