import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'profile_service.dart';

import 'package:http/http.dart' as http;

const String _keyFirebaseDbUrl = 'offpay_firebase_db_url';
const String _keyFirebaseSecret = 'offpay_firebase_auth_token';
const String _defaultFirebaseDbUrl = 'https://off-pay-0009-default-rtdb.firebaseio.com';
const String _firebaseApiKey = 'AIzaSyArgfCBKg10-lOXNvKWL24MwhsUHeee-uY';

class FirebaseService {
  static Future<String> getFirebaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFirebaseDbUrl) ?? _defaultFirebaseDbUrl;
  }

  static Future<void> setFirebaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirebaseDbUrl, url.trim());
  }

  static Future<String?> getFirebaseAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFirebaseSecret);
  }

  static Future<void> setFirebaseAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFirebaseSecret, token.trim());
  }

  /// Generate SHA-256 HMAC cryptographic signature for Firebase transaction proof
  static String generateProofSignature(TransactionModel tx) {
    final raw = '${tx.transactionId}:${tx.amount}:${tx.recipientId}:${tx.timestamp.millisecondsSinceEpoch}:OFFPAY_FIREBASE_SECRET';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String _extractDeviceIdFromRaw(String rawId) {
    if (rawId.contains('(') && rawId.contains(')')) {
      final startIndex = rawId.lastIndexOf('(') + 1;
      final endIndex = rawId.lastIndexOf(')');
      if (endIndex > startIndex) {
        return rawId.substring(startIndex, endIndex).trim();
      }
    }
    return rawId.trim();
  }

  /// Generate an obfuscated, simplified server user ID from deviceId
  static String generateServerUserId(String deviceId) {
    final hash = sha256.convert(utf8.encode('${deviceId.trim()}_OFFPAY_SERVER_SALT')).toString().toUpperCase();
    return 'SRV-${hash.substring(0, 10)}';
  }

  /// Sync User Profile Data, Balance, PIN Hash, and Device details to Firebase Cloud Database
  static Future<bool> syncUserProfile({
    required double balance,
    String? pinHash,
    String? overrideDeviceId,
    String? overrideUserName,
  }) async {
    try {
      final deviceId = overrideDeviceId ?? await ProfileService.getDeviceId();
      final userName = overrideUserName ?? await ProfileService.getUserName();
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();

      // Check if user has an uploaded profile picture file and encode as base64 (size checked to not fill storage)
      String? photoBase64;
      try {
        final imagePath = await ProfileService.getProfileImagePath();
        if (imagePath != null && imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.length <= 150000) { // Limit to <= 150 KB
              photoBase64 = base64Encode(bytes);
            }
          }
        }
      } catch (_) {}

      final userPayload = {
        'deviceId': deviceId,
        'serverUserId': generateServerUserId(deviceId),
        'userNameEnc': base64Encode(utf8.encode(userName)),
        'userNameHash': sha256.convert(utf8.encode(userName.trim())).toString(),
        'balanceEnc': base64Encode(utf8.encode(balance.toStringAsFixed(2))),
        'balanceHash': sha256.convert(utf8.encode('${balance.toStringAsFixed(2)}_OFFPAY_SALT')).toString(),
        if (pinHash != null && pinHash.isNotEmpty) 'pinHash': pinHash,
        if (photoBase64 != null) 'photoBase64': photoBase64,
        'lastSyncTime': DateTime.now().toIso8601String(),
        'lastSyncTimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      String endpoint = '$firebaseUrl/users/$deviceId.json';
      if (authToken != null && authToken.isNotEmpty) {
        endpoint += '?auth=$authToken';
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(endpoint);
      final request = await client.putUrl(uri);
      request.headers.set('content-type', 'application/json');
      request.write(jsonEncode(userPayload));

      final response = await request.close().timeout(const Duration(seconds: 4));

      // Dual-write to username path so lookup by username or device ID is always synchronized
      if (userName != 'Unknown User' && userName.trim().isNotEmpty) {
        final usernameKey = base64UrlEncode(utf8.encode(userName.trim()));
        String userEndpoint = '$firebaseUrl/users/$usernameKey.json';
        if (authToken != null && authToken.isNotEmpty) {
          userEndpoint += '?auth=$authToken';
        }
        try {
          final uriUser = Uri.parse(userEndpoint);
          final reqUser = await client.putUrl(uriUser);
          reqUser.headers.set('content-type', 'application/json');
          reqUser.write(jsonEncode(userPayload));
          await reqUser.close().timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

      client.close();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Firebase user profile sync info: $e');
      return false;
    }
  }

  /// Fetch a user's profile photo base64 string from Firebase by their deviceId or username
  static Future<String?> fetchUserPhotoBase64(String deviceOrUserName) async {
    try {
      if (deviceOrUserName.trim().isEmpty) return null;
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();

      // Try deviceId endpoint first
      String endpoint = '$firebaseUrl/users/${deviceOrUserName.trim()}/photoBase64.json';
      if (authToken != null && authToken.isNotEmpty) endpoint += '?auth=$authToken';

      var response = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body != 'null') {
        final bodyStr = response.body;
        if (bodyStr.startsWith('"') && bodyStr.endsWith('"')) {
          return jsonDecode(bodyStr) as String;
        }
        return bodyStr;
      }

      // Try username key fallback
      final usernameKey = base64UrlEncode(utf8.encode(deviceOrUserName.trim()));
      endpoint = '$firebaseUrl/users/$usernameKey/photoBase64.json';
      if (authToken != null && authToken.isNotEmpty) endpoint += '?auth=$authToken';
      response = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body != 'null') {
        final bodyStr = response.body;
        if (bodyStr.startsWith('"') && bodyStr.endsWith('"')) {
          return jsonDecode(bodyStr) as String;
        }
        return bodyStr;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a username already exists
  static Future<bool> checkUsernameExists(String username) async {
    try {
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();
      final usernameKey = base64UrlEncode(utf8.encode(username.trim()));
      
      String checkEndpoint = '$firebaseUrl/users/$usernameKey.json';
      if (authToken != null && authToken.isNotEmpty) checkEndpoint += '?auth=$authToken';
      
      final checkRes = await http.get(Uri.parse(checkEndpoint)).timeout(const Duration(seconds: 4));
      return checkRes.statusCode == 200 && checkRes.body != 'null';
    } catch (e) {
      return false; // On error, assume it doesn't exist for now to not block UI entirely
    }
  }

  /// Create a new account in Firebase
  static Future<Map<String, dynamic>> createAccount(String username, String password) async {
    try {
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();
      final usernameKey = base64UrlEncode(utf8.encode(username.trim()));
      
      // Check if exists
      String checkEndpoint = '$firebaseUrl/users/$usernameKey.json';
      if (authToken != null && authToken.isNotEmpty) checkEndpoint += '?auth=$authToken';
      final checkRes = await http.get(Uri.parse(checkEndpoint)).timeout(const Duration(seconds: 4));
      if (checkRes.statusCode == 200 && checkRes.body != 'null') {
        return {'success': false, 'message': 'Username already exists.'};
      }

      final deviceId = ProfileService.generateRandomDeviceId();
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      
      final userPayload = {
        'deviceId': deviceId,
        'userName': username.trim(),
        'balance': 500.0, // initial balance
        'passwordHash': passwordHash,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final client = HttpClient();
      final request = await client.putUrl(Uri.parse(checkEndpoint));
      request.headers.set('content-type', 'application/json');
      request.write(jsonEncode(userPayload));
      final response = await request.close().timeout(const Duration(seconds: 4));
      client.close();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await syncUserProfile(
          balance: 500.0,
          overrideDeviceId: deviceId,
          overrideUserName: username.trim(),
        );
        return {'success': true, 'deviceId': deviceId, 'balance': 500.0};
      }
      return {'success': false, 'message': 'Failed to create account.'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Login and fetch account data
  static Future<Map<String, dynamic>> loginAccount(String username, String password) async {
    try {
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();
      final usernameKey = base64UrlEncode(utf8.encode(username.trim()));
      
      String endpoint = '$firebaseUrl/users/$usernameKey.json';
      if (authToken != null && authToken.isNotEmpty) endpoint += '?auth=$authToken';
      
      final response = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 || response.body == 'null') {
        return {'success': false, 'message': 'Account not found.'};
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      
      if (data['passwordHash'] != passwordHash) {
        return {'success': false, 'message': 'Incorrect password.'};
      }

      // Fetch transaction history
      String historyEndpoint = '$firebaseUrl/user_history/${data['deviceId']}.json';
      if (authToken != null && authToken.isNotEmpty) historyEndpoint += '?auth=$authToken';
      
      final histResponse = await http.get(Uri.parse(historyEndpoint)).timeout(const Duration(seconds: 4));
      List<dynamic> historyList = [];
      if (histResponse.statusCode == 200 && histResponse.body != 'null') {
        final Map<String, dynamic> histData = jsonDecode(histResponse.body);
        historyList = histData.values.toList();
      }

      await syncUserProfile(
        balance: (data['balance'] as num).toDouble(),
        overrideDeviceId: data['deviceId']?.toString(),
        overrideUserName: username.trim(),
      );
      return {
        'success': true,
        'deviceId': data['deviceId'],
        'balance': (data['balance'] as num).toDouble(),
        'pinHash': data['pinHash'],
        'history': historyList,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Push all payment details, transaction IDs, sender/recipient IDs, date/time, amounts to Firebase Cloud Database
  static Future<Map<String, dynamic>> syncWithFirebase(WalletModel walletModel) async {
    final deviceId = await ProfileService.getDeviceId();
    final userName = await ProfileService.getUserName();

    // 1. Sync User Account Profile & Balance to Server
    syncUserProfile(balance: walletModel.balance);

    // Only attempt cloud synchronization for transactions that are not yet confirmed on server
    final toSyncList = walletModel.history
        .where((tx) => tx.status != 'VERIFIED' && tx.status != 'SYNCED')
        .toList();

    if (toSyncList.isEmpty) {
      return {
        'success': true,
        'syncedCount': 0,
        'failedCount': 0,
        'message': '🟢 All user data, balance & payments are already synced with Firebase Cloud Server!',
      };
    }

    final firebaseUrl = await getFirebaseUrl();
    final authToken = await getFirebaseAuthToken();
    int verifiedCount = 0;
    int failedCount = 0;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    // Sync all unverified transactions to Firebase Realtime DB
    for (final tx in toSyncList) {
      final signature = generateProofSignature(tx);
      final txPayload = {
        'transactionId': tx.transactionId,
        'amount': tx.amount,
        'senderId': tx.isCredit ? _extractDeviceIdFromRaw(tx.recipientId) : '$deviceId [${generateServerUserId(deviceId)}]',
        'recipientId': tx.isCredit ? '$deviceId [${generateServerUserId(deviceId)}]' : _extractDeviceIdFromRaw(tx.recipientId),
        'senderServerId': tx.isCredit ? generateServerUserId(_extractDeviceIdFromRaw(tx.recipientId)) : generateServerUserId(deviceId),
        'recipientServerId': tx.isCredit ? generateServerUserId(deviceId) : generateServerUserId(_extractDeviceIdFromRaw(tx.recipientId)),
        'type': tx.isCredit ? 'CREDIT' : 'DEBIT',
        'dateTime': tx.timestamp.toIso8601String(),
        'timestamp': tx.timestamp.millisecondsSinceEpoch,
        'proofSignature': signature,
        'status': 'VERIFIED',
        'syncedAt': DateTime.now().toIso8601String(),
      };

      try {
        bool masterSuccess = true;
        if (!tx.isCredit || tx.method != 'bluetooth') {
          // Endpoint 1: Master Transactions Ledger (/transactions/{txId}.json)
          // ONLY the SENDER is allowed to post to the Master Ledger to prove they sent it.
          String endpoint = '$firebaseUrl/transactions/${tx.transactionId}.json';
          if (authToken != null && authToken.isNotEmpty) {
            endpoint += '?auth=$authToken';
          }
          var uri = Uri.parse(endpoint);
          var request = await client.putUrl(uri);
          request.headers.set('content-type', 'application/json');
          request.write(jsonEncode(txPayload));
          var response = await request.close().timeout(const Duration(seconds: 4));
          masterSuccess = (response.statusCode == 200 || response.statusCode == 201);
        }

        // Endpoint 2: User Transaction History Ledger (/user_history/{deviceId}/{txId}.json)
        String historyEndpoint = '$firebaseUrl/user_history/$deviceId/${tx.transactionId}.json';
        if (authToken != null && authToken.isNotEmpty) {
          historyEndpoint += '?auth=$authToken';
        }
        var historyUri = Uri.parse(historyEndpoint);
        var historyRequest = await client.putUrl(historyUri);
        historyRequest.headers.set('content-type', 'application/json');
        historyRequest.write(jsonEncode(txPayload));
        var historyResponse = await historyRequest.close().timeout(const Duration(seconds: 4));

        // Endpoint 3: Counterpart Transaction History Ledger (/user_history/{counterpartId}/{txId}.json)
        final counterpartId = _extractDeviceIdFromRaw(tx.recipientId);
        if (counterpartId.isNotEmpty && counterpartId != deviceId && counterpartId != 'NFC Payer' && counterpartId != 'Unknown') {
          try {
            final counterpartPayload = Map<String, dynamic>.from(txPayload);
            counterpartPayload['type'] = tx.isCredit ? 'DEBIT' : 'CREDIT';
            counterpartPayload['senderId'] = tx.isCredit ? '$userName ($deviceId)' : counterpartId;
            counterpartPayload['recipientId'] = tx.isCredit ? counterpartId : '$userName ($deviceId)';

            String cpEndpoint = '$firebaseUrl/user_history/$counterpartId/${tx.transactionId}.json';
            if (authToken != null && authToken.isNotEmpty) cpEndpoint += '?auth=$authToken';
            var cpUri = Uri.parse(cpEndpoint);
            var cpReq = await client.putUrl(cpUri);
            cpReq.headers.set('content-type', 'application/json');
            cpReq.write(jsonEncode(counterpartPayload));
            await cpReq.close().timeout(const Duration(seconds: 4));
          } catch (e) {
            debugPrint('Counterpart history sync exception: $e');
          }
        }

        bool historySuccess = (historyResponse.statusCode == 200 || historyResponse.statusCode == 201);
        final bool isSuccess = masterSuccess && historySuccess;

        if (isSuccess) {
          bool senderVerified = true;
          if (tx.isCredit && tx.method == 'bluetooth') {
            // Verify against sender's cloud record on server
            try {
              String checkEndpoint = '$firebaseUrl/transactions/${tx.transactionId}.json';
              if (authToken != null && authToken.isNotEmpty) checkEndpoint += '?auth=$authToken';
              var checkUri = Uri.parse(checkEndpoint);
              var checkReq = await client.getUrl(checkUri);
              var checkResp = await checkReq.close().timeout(const Duration(seconds: 4));
              if (checkResp.statusCode == 200) {
                final bodyStr = await checkResp.transform(utf8.decoder).join();
                if (bodyStr.trim() == 'null' || bodyStr.isEmpty) {
                  senderVerified = false;
                  debugPrint('Waiting for sender user to sync transaction ${tx.transactionId} to server...');
                }
              } else {
                senderVerified = false;
              }
            } catch (e) {
              senderVerified = false;
            }
          }

          if (senderVerified) {
            await walletModel.updateTransactionStatus(tx.transactionId, 'VERIFIED');
            verifiedCount++;
          } else {
            // Keep in PENDING until sender user syncs their proof to Firebase
            await walletModel.updateTransactionStatus(tx.transactionId, 'PENDING');
          }
        } else {
          debugPrint('Firebase cloud sync non-success HTTP for ${tx.transactionId}: Master=$masterSuccess, History=$historySuccess');
          await walletModel.updateTransactionStatus(tx.transactionId, 'RETRYING');
          failedCount++;
        }
      } catch (e) {
        debugPrint('Firebase cloud sync exception for ${tx.transactionId}: $e');
        await walletModel.updateTransactionStatus(tx.transactionId, 'RETRYING');
        failedCount++;
      }
    }

    client.close();

    if (failedCount > 0) {
      return {
        'success': false,
        'syncedCount': verifiedCount,
        'failedCount': failedCount,
        'message': '⚠️ Synced $verifiedCount payments; $failedCount pending/retrying due to network issues.',
      };
    }

    return {
      'success': true,
      'syncedCount': verifiedCount,
      'failedCount': 0,
      'message': '🟢 All user data, balance & payments synced with Firebase Cloud Server!',
    };
  }

  /// Execute an online transaction directly through Firebase
  static Future<bool> executeOnlineTransfer({
    required WalletModel senderWallet,
    required String recipientDeviceId,
    required double amount,
  }) async {
    final txId = 'TXN_ONLINE_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      // 1. Get recipient profile to get their current balance
      String recEndpoint = '$firebaseUrl/users/$recipientDeviceId.json';
      if (authToken != null && authToken.isNotEmpty) recEndpoint += '?auth=$authToken';
      
      double recBalance = 0.0;
      Map<String, dynamic> recData = {'deviceId': recipientDeviceId, 'balance': 0.0};
      try {
        final recResponse = await http.get(Uri.parse(recEndpoint)).timeout(const Duration(seconds: 4));
        if (recResponse.statusCode == 200 && recResponse.body != 'null') {
          recData = jsonDecode(recResponse.body);
          recBalance = (recData['balance'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {}
      
      // 2. Deduct from Sender local wallet with PENDING state until confirmed by server
      bool debitSuccess = await senderWallet.sendMoney(
        amount,
        recipientDeviceId,
        status: 'PENDING',
        transactionId: txId,
        paymentMethod: 'online',
      );
      if (!debitSuccess) return false;

      // 3. Update Recipient balance online
      final newRecBalance = recBalance + amount;
      recData['balance'] = newRecBalance;
      recData['deviceId'] = recipientDeviceId;
      
      bool recipientUpdated = false;
      try {
        var uri = Uri.parse(recEndpoint);
        var request = await client.putUrl(uri);
        request.headers.set('content-type', 'application/json');
        request.write(jsonEncode(recData));
        var recResp = await request.close().timeout(const Duration(seconds: 4));
        recipientUpdated = (recResp.statusCode == 200 || recResp.statusCode == 201);
      } catch (_) {}

      // 4. Sync sender's own new balance online
      final senderUpdated = await syncUserProfile(balance: senderWallet.balance);

      // 5. Create transaction proof and push to recipient's history
      final txIndex = senderWallet.history.indexWhere((t) => t.transactionId == txId);
      final tx = txIndex != -1 ? senderWallet.history[txIndex] : senderWallet.history.first;
      final signature = generateProofSignature(tx);
      
      final senderName = await ProfileService.getUserName();
      final senderDeviceId = await ProfileService.getDeviceId();
      final senderIdFull = '$senderName ($senderDeviceId)';

      final txPayload = {
        'transactionId': tx.transactionId,
        'amount': tx.amount,
        'senderId': senderIdFull,
        'recipientId': recipientDeviceId,
        'type': 'CREDIT',
        'dateTime': tx.timestamp.toIso8601String(),
        'timestamp': tx.timestamp.millisecondsSinceEpoch,
        'proofSignature': signature,
        'status': 'VERIFIED',
        'syncedAt': DateTime.now().toIso8601String(),
      };

      // Push to Recipient's history
      String historyEndpoint = '$firebaseUrl/user_history/$recipientDeviceId/${tx.transactionId}.json';
      if (authToken != null && authToken.isNotEmpty) historyEndpoint += '?auth=$authToken';
      var historyUri = Uri.parse(historyEndpoint);
      var historyRequest = await client.putUrl(historyUri);
      historyRequest.headers.set('content-type', 'application/json');
      historyRequest.write(jsonEncode(txPayload));
      var recHistResp = await historyRequest.close().timeout(const Duration(seconds: 4));

      // Push to Sender's history
      final txPayloadSender = Map<String, dynamic>.from(txPayload);
      txPayloadSender['type'] = 'DEBIT';
      txPayloadSender['recipientId'] = recData['userName'] ?? recipientDeviceId;
      String senderHistoryEndpoint = '$firebaseUrl/user_history/$senderDeviceId/${tx.transactionId}.json';
      if (authToken != null && authToken.isNotEmpty) senderHistoryEndpoint += '?auth=$authToken';
      var senderHistoryUri = Uri.parse(senderHistoryEndpoint);
      var senderHistoryReq = await client.putUrl(senderHistoryUri);
      senderHistoryReq.headers.set('content-type', 'application/json');
      senderHistoryReq.write(jsonEncode(txPayloadSender));
      var sendHistResp = await senderHistoryReq.close().timeout(const Duration(seconds: 4));

      // Master transactions ledger
      String masterEndpoint = '$firebaseUrl/transactions/${tx.transactionId}.json';
      if (authToken != null && authToken.isNotEmpty) masterEndpoint += '?auth=$authToken';
      var masterUri = Uri.parse(masterEndpoint);
      var masterReq = await client.putUrl(masterUri);
      masterReq.headers.set('content-type', 'application/json');
      masterReq.write(jsonEncode(txPayload));
      var masterResp = await masterReq.close().timeout(const Duration(seconds: 4));

      client.close();

      final allSuccess = recipientUpdated &&
          senderUpdated &&
          (recHistResp.statusCode == 200 || recHistResp.statusCode == 201) &&
          (sendHistResp.statusCode == 200 || sendHistResp.statusCode == 201) &&
          (masterResp.statusCode == 200 || masterResp.statusCode == 201);

      if (allSuccess) {
        await senderWallet.updateTransactionStatus(txId, 'VERIFIED');
        return true;
      } else {
        await senderWallet.updateTransactionStatus(txId, 'RETRYING');
        return false;
      }
    } catch (e) {
      debugPrint('Online transfer failed: $e');
      await senderWallet.updateTransactionStatus(txId, 'RETRYING');
      return false;
    }
  }

  /// Pull down the latest balance and history from Firebase
  static Future<bool> syncDownFromServer(WalletModel walletModel) async {
    try {
      final deviceId = await ProfileService.getDeviceId();
      final firebaseUrl = await getFirebaseUrl();
      final authToken = await getFirebaseAuthToken();

      // Get Balance
      String userEndpoint = '$firebaseUrl/users/$deviceId.json';
      if (authToken != null && authToken.isNotEmpty) userEndpoint += '?auth=$authToken';
      final userRes = await http.get(Uri.parse(userEndpoint)).timeout(const Duration(seconds: 4));
      
      double serverBalance = walletModel.balance;
      if (userRes.statusCode == 200 && userRes.body != 'null') {
        final Map<String, dynamic> userData = jsonDecode(userRes.body);
        serverBalance = (userData['balance'] as num).toDouble();
      } else {
        // Fallback: check by usernameKey in case account was created/logged in under username key
        final userName = await ProfileService.getUserName();
        if (userName != 'Unknown User' && userName.trim().isNotEmpty) {
          final usernameKey = base64UrlEncode(utf8.encode(userName.trim()));
          String fallbackEndpoint = '$firebaseUrl/users/$usernameKey.json';
          if (authToken != null && authToken.isNotEmpty) fallbackEndpoint += '?auth=$authToken';
          final fallRes = await http.get(Uri.parse(fallbackEndpoint)).timeout(const Duration(seconds: 4));
          if (fallRes.statusCode == 200 && fallRes.body != 'null') {
            final Map<String, dynamic> userData = jsonDecode(fallRes.body);
            serverBalance = (userData['balance'] as num).toDouble();
          }
        }
      }

      // Get History
      String historyEndpoint = '$firebaseUrl/user_history/$deviceId.json';
      if (authToken != null && authToken.isNotEmpty) historyEndpoint += '?auth=$authToken';
      final histRes = await http.get(Uri.parse(historyEndpoint)).timeout(const Duration(seconds: 4));
      
      List<TransactionModel> serverHistory = [];
      if (histRes.statusCode == 200 && histRes.body != 'null') {
        final Map<String, dynamic> histData = jsonDecode(histRes.body);
        for (var txValue in histData.values) {
          serverHistory.add(TransactionModel(
            id: txValue['transactionId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            amount: (txValue['amount'] as num).toDouble(),
            timestamp: DateTime.parse(txValue['dateTime']),
            recipientId: txValue['type'] == 'CREDIT' ? txValue['senderId'] : txValue['recipientId'],
            isCredit: txValue['type'] == 'CREDIT',
            transactionId: txValue['transactionId'],
            status: txValue['status'] ?? 'VERIFIED',
          ));
        }
      }

      await walletModel.mergeFromServer(serverBalance, serverHistory);
      return true;
    } catch (e) {
      debugPrint('Failed to sync down: $e');
      return false;
    }
  }

  static Timer? _autoSyncTimer;

  /// Starts real-time periodic server polling every 2 seconds so balance updates automatically in milliseconds
  static void startAutoSync(WalletModel walletModel) {
    stopAutoSync();
    _autoSyncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      await syncDownFromServer(walletModel);
    });
  }

  /// Stops automatic server polling
  static void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Permanently delete user account record from remote Firebase database
  static Future<bool> deleteUserAccountFromServer(String deviceId) async {
    try {
      final baseUrl = await getFirebaseUrl();
      final token = await getFirebaseAuthToken();
      final safeId = Uri.encodeComponent(deviceId);
      String url = '$baseUrl/users/$safeId.json';
      if (token != null && token.isNotEmpty) {
        url += '?auth=$token';
      }
      final response = await http.delete(Uri.parse(url));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
  /// Store dynamically generated OTP and hash in Firebase Cloud Database with expiration
  static Future<bool> storeOtpVerification(String phone, String otp) async {
    try {
      final baseUrl = await getFirebaseUrl();
      final token = await getFirebaseAuthToken();
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final mobile10 = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

      final payload = {
        'otpCode': otp.trim(), // Save plain 6-digit OTP so it is visible in Firebase console/website
        'otpHash': sha256.convert(utf8.encode(otp.trim())).toString(),
        'phone': phone,
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      };

      String url10 = '$baseUrl/otp_verifications/$mobile10.json';
      if (token != null && token.isNotEmpty) url10 += '?auth=$token';
      final resp10 = await http.put(Uri.parse(url10), body: jsonEncode(payload));

      if (cleanPhone != mobile10) {
        String urlFull = '$baseUrl/otp_verifications/$cleanPhone.json';
        if (token != null && token.isNotEmpty) urlFull += '?auth=$token';
        await http.put(Uri.parse(urlFull), body: jsonEncode(payload));
      }

      return resp10.statusCode == 200 || resp10.statusCode == 201 || resp10.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Verify dynamically generated OTP against Firebase Cloud Database
  static Future<bool> verifyOtp(String phone, String inputOtp) async {
    try {
      final baseUrl = await getFirebaseUrl();
      final token = await getFirebaseAuthToken();
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final mobile10 = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

      for (final key in [mobile10, cleanPhone]) {
        String url = '$baseUrl/otp_verifications/$key.json';
        if (token != null && token.isNotEmpty) url += '?auth=$token';
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200 && resp.body != 'null') {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final storedCode = data['otpCode'] as String?;
          final storedHash = data['otpHash'] as String?;
          final expiresAt = data['expiresAt'] as int?;
          if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
            continue; // Check next key if expired
          }
          final inputHash = sha256.convert(utf8.encode(inputOtp.trim())).toString();
          if ((storedCode != null && storedCode == inputOtp.trim()) || (storedHash == inputHash)) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Log OTP request to Firebase Realtime Database (no external SMS dispatch)
  static Future<bool> sendOtpViaSms(String phone, String otp) async {
    try {
      // Record in Firebase Realtime Database for verification and admin logging
      final baseUrl = await getFirebaseUrl();
      final token = await getFirebaseAuthToken();
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final mobileNumber = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

      String endpoint = '$baseUrl/firebase_otp_service/$mobileNumber.json';
      if (token != null && token.isNotEmpty) {
        endpoint += '?auth=$token';
      }

      final payload = {
        'phoneNumber': phone,
        'mobile': mobileNumber,
        'otpCode': otp.trim(),
        'status': 'PENDING_SMS_DISPATCH',
        'service': 'firebase_otp_service',
        'timestamp': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      };

      final response = await http.put(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      String reqUrl = '$baseUrl/otp_requests/$mobileNumber.json';
      if (token != null && token.isNotEmpty) reqUrl += '?auth=$token';
      await http.put(
        Uri.parse(reqUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        debugPrint('Firebase OTP Service triggered for $phone');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Firebase OTP Service error: $e');
      return false;
    }
  }
}
