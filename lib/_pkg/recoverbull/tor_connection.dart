import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:recoverbull/recoverbull.dart';

class TorConnection {
  static final TorConnection _instance = TorConnection._internal();
  factory TorConnection() => _instance;

  TorConnection._internal();

  Tor? _tor;
  Timer? _keepAliveTimer;
  final _connectionCompleter = Completer<void>();

  bool get isInitialized => _tor != null && _tor!.started;
  Tor? get tor => _tor;

  Future<void> get ready => _connectionCompleter.future;

  Future<void> initialize() async {
    if (isInitialized) return;

    try {
      debugPrint('Initializing Tor...');
      await Tor.init();
      await Tor.instance.start();
      _tor = Tor.instance;

      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.complete();
      }
    } catch (e) {
      debugPrint('Failed to initialize Tor: $e');
      await dispose();
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.completeError(e);
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    _keepAliveTimer?.cancel();
    if (_tor != null) {
      _tor!.stop();
      _tor = null;
    }
  }
}
