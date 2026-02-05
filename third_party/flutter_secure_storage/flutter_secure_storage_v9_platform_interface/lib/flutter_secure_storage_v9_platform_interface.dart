library flutter_secure_storage_v9_platform_interface;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

part './src/method_channel_flutter_secure_storage_v9.dart';
part './src/options.dart';

/// The interface that implementations of flutter_secure_storage_v9 must implement.
///
/// Platform implementations should extend this class rather than implement it as `flutter_secure_storage_v9`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [FlutterSecureStorageV9Platform] methods.
abstract class FlutterSecureStorageV9Platform extends PlatformInterface {
  FlutterSecureStorageV9Platform() : super(token: _token);

  static final Object _token = Object();

  static FlutterSecureStorageV9Platform _instance =
      MethodChannelFlutterSecureStorageV9();

  static FlutterSecureStorageV9Platform get instance => _instance;

  static set instance(FlutterSecureStorageV9Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  });

  Future<String?> read({
    required String key,
    required Map<String, String> options,
  });

  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  });

  Future<void> delete({
    required String key,
    required Map<String, String> options,
  });

  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  });

  Future<void> deleteAll({
    required Map<String, String> options,
  });
}
