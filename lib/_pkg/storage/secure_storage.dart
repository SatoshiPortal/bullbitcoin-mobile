import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage implements IStorage {
  final storage = const FlutterSecureStorage();

  @override
  Future<Err?> saveValue({
    required StorageKeys key,
    required String value,
  }) async {
    try {
      await storage.write(
        key: key.name,
        value: value,
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  @override
  Future<(Map<String, String>?, Err?)> getAll() async {
    try {
      final value = await storage.readAll();
      return (value, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  @override
  Future<(String?, Err?)> getValue(
    StorageKeys key,
  ) async {
    try {
      final value = await storage.read(
        key: key.name,
      );

      if (value == null) throw 'No Key';

      return (value, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e == 'No Key'));
    }
  }

  @override
  Future<Err?> deleteValue(
    StorageKeys key,
  ) async {
    try {
      final _ = await storage.delete(
        key: key.name,
      );

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  @override
  Future<Err?> deleteAll() async {
    try {
      await storage.deleteAll();

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  @override
  Future<Err?> saveWallet({
    required String key,
    required String value,
  }) async {
    try {
      await storage.write(
        key: key,
        value: value,
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  @override
  Future<(String?, Err?)> getWallet(
    String key,
  ) async {
    try {
      final value = await storage.read(
        key: key,
      );

      if (value == null) throw 'No Key';

      return (value, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  @override
  Future<Err?> deleteWallet(
    String key,
  ) async {
    try {
      final _ = await storage.delete(
        key: key,
      );

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
