import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:hive/hive.dart';

class HiveStorage implements IStorage {
  HiveStorage({required String password}) {
    _init(password);
  }

  late Box<String>? _box;

  void _init(String password) async {
    final cipher = HiveAesCipher(password.codeUnits);
    _box = await Hive.openBox('store', encryptionCipher: cipher);
  }

  @override
  Future<Err?> deleteAll() async {
    try {
      await _box!.clear();
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  @override
  Future<Err?> deleteValue(String key) async {
    try {
      await _box!.delete(key);
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  @override
  Future<(Map<String, String>?, Err?)> getAll() async {
    try {
      final Map<String, String> data = {};
      _box!.toMap().forEach((key, value) {
        data[key as String] = value;
      });
      return (data, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  @override
  Future<(String?, Err?)> getValue(String key) async {
    try {
      final value = _box!.get(key);
      if (value == null) throw 'Key not found';
      return (value, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  @override
  Future<Err?> saveValue({required String key, required String value}) async {
    try {
      await _box!.put(key, value);
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
