import 'package:recoverbull/recoverbull.dart';

abstract class TorRepository {
  Future<void> start();

  /// Checks if the Tor connection is ready for use
  Future<bool> get isTorReady;
  bool get isStarted;

  /// Creates a SOCKS socket using the Tor connection
  Future<SOCKSSocket> createSocket();

  Future<void> stop();
}
