import 'recoverbull_tor_route.dart';

/// Keeps a flow route alive for one key-server operation.
abstract interface class RecoverBullRoutePort {
  Future<T> borrowRoute<T>(
    Future<T> Function(RecoverBullTorRoute? route) operation,
  );
}
