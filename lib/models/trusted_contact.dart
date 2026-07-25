import 'package:hive_flutter/hive_flutter.dart';

class TrustedContact {
  final String name;
  final String deviceId;
  final DateTime addedOn;
  final int totalTransactions;

  TrustedContact({
    required this.name,
    required this.deviceId,
    required this.addedOn,
    required this.totalTransactions,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'deviceId': deviceId,
      'addedOn': addedOn.toIso8601String(),
      'totalTransactions': totalTransactions,
    };
  }

  factory TrustedContact.fromMap(Map<String, dynamic> map) {
    return TrustedContact(
      name: map['name'] as String,
      deviceId: map['deviceId'] as String,
      addedOn: DateTime.parse(map['addedOn'] as String),
      totalTransactions: map['totalTransactions'] as int,
    );
  }
}

class TrustedContactService {
  static const String _boxName = 'trusted_contacts';

  static Future<void> init() async {
    await Hive.openBox<Map>(_boxName);
  }

  static Future<void> addContact(TrustedContact contact) async {
    final box = Hive.box<Map>(_boxName);
    await box.put(contact.deviceId, contact.toMap());
  }

  static Future<void> removeContact(String deviceId) async {
    final box = Hive.box<Map>(_boxName);
    await box.delete(deviceId);
  }

  static List<TrustedContact> getContacts() {
    final box = Hive.box<Map>(_boxName);
    return box.values.map((map) {
      final castedMap = Map<String, dynamic>.from(map);
      return TrustedContact.fromMap(castedMap);
    }).toList();
  }

  static bool isContactSaved(String deviceId) {
    final box = Hive.box<Map>(_boxName);
    return box.containsKey(deviceId);
  }

  static Future<void> incrementTransactions(String deviceId) async {
    final box = Hive.box<Map>(_boxName);
    final data = box.get(deviceId);
    if (data != null) {
      final castedMap = Map<String, dynamic>.from(data);
      final contact = TrustedContact.fromMap(castedMap);
      final updatedContact = TrustedContact(
        name: contact.name,
        deviceId: contact.deviceId,
        addedOn: contact.addedOn,
        totalTransactions: contact.totalTransactions + 1,
      );
      await box.put(deviceId, updatedContact.toMap());
    }
  }
}
