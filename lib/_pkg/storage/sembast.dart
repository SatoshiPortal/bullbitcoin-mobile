import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';

class SembastStorage implements IStorage {
  @override
  Future<Err?> deleteAll() {
    // TODO: implement deleteAll
    throw UnimplementedError();
  }

  @override
  Future<Err?> deleteValue(String key) {
    // TODO: implement deleteValue
    throw UnimplementedError();
  }

  @override
  Future<(Map<String, String>?, Err?)> getAll() {
    // TODO: implement getAll
    throw UnimplementedError();
  }

  @override
  Future<(String?, Err?)> getValue(String key) {
    // TODO: implement getValue
    throw UnimplementedError();
  }

  @override
  Future<Err?> saveValue({required String key, required String value}) {
    // TODO: implement saveValue
    throw UnimplementedError();
  }
}
