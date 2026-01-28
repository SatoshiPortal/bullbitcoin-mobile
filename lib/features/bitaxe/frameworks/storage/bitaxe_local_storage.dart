import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_local_storage_port.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/bitaxe_device.dart';

/// Local storage for Bitaxe connections
/// This is a secondary adapter - implements the BitaxeLocalStoragePort
class BitaxeLocalStorage implements BitaxeLocalStoragePort {
  final KeyValueStorageDatasource<String> _secureStorage;
  static const String _storageKey = 'bitaxe_connection';

  BitaxeLocalStorage({required KeyValueStorageDatasource<String> secureStorage})
    : _secureStorage = secureStorage;

  @override
  Future<void> storeConnection(BitaxeDevice device) async {
    final json = {
      'ipAddress': device.ipAddress,
      'hostname': device.hostname,
      'lastConnected': device.lastConnected?.toIso8601String(),
      // Note: SystemInfo is not stored, it's fetched fresh each time
    };
    await _secureStorage.saveValue(key: _storageKey, value: jsonEncode(json));
  }

  @override
  Future<BitaxeDevice?> getStoredConnection() async {
    final jsonString = await _secureStorage.getValue(_storageKey);
    if (jsonString == null) return null;

    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    // Return device without SystemInfo - it will be fetched fresh when needed
    return BitaxeDevice(
      ipAddress: json['ipAddress'] as String,
      hostname: json['hostname'] as String,
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
    );
  }

  @override
  Future<void> removeConnection() async {
    await _secureStorage.deleteValue(_storageKey);
  }

  @override
  Future<bool> hasStoredConnection() async {
    return await _secureStorage.hasValue(_storageKey);
  }
}
