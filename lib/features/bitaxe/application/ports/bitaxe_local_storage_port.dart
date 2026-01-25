import 'package:bb_mobile/features/bitaxe/domain/entities/bitaxe_device.dart';

/// Port (interface) for local storage operations
abstract class BitaxeLocalStoragePort {
  /// Store connected device information
  Future<void> storeConnection(BitaxeDevice device);

  /// Get stored connection
  Future<BitaxeDevice?> getStoredConnection();

  /// Remove stored connection
  Future<void> removeConnection();

  /// Check if a connection is stored
  Future<bool> hasStoredConnection();
}
