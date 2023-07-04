import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';

class SembastStorage implements IStorage {
  @override
  Future<Err?> deleteAll() {
    // TODO: implement deleteAll
    throw UnimplementedError();
  }

  @override
  Future<Err?> deleteValue(StorageKeys key) {
    // TODO: implement deleteValue
    throw UnimplementedError();
  }

  @override
  Future<Err?> deleteWallet(String key) {
    // TODO: implement deleteWallet
    throw UnimplementedError();
  }

  @override
  Future<(Map<String, String>?, Err?)> getAll() {
    // TODO: implement getAll
    throw UnimplementedError();
  }

  @override
  Future<(String?, Err?)> getValue(StorageKeys key) {
    // TODO: implement getValue
    throw UnimplementedError();
  }

  @override
  Future<(String?, Err?)> getWallet(String key) {
    // TODO: implement getWallet
    throw UnimplementedError();
  }

  @override
  Future<Err?> saveValue({required StorageKeys key, required String value}) {
    // TODO: implement saveValue
    throw UnimplementedError();
  }

  @override
  Future<Err?> saveWallet({required String key, required String value}) {
    // TODO: implement saveWallet
    throw UnimplementedError();
  }
}
