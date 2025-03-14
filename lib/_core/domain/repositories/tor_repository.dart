import 'package:recoverbull/recoverbull.dart';

abstract class TorRepository {
  /// Checks if the Tor connection is ready for use
  Future<bool> isTorReady();

  /// Creates a SOCKS socket using the Tor connection
  Future<SOCKSSocket> createSocket();
}
