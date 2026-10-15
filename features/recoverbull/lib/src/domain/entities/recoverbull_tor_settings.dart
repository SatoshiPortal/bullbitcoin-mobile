import 'package:meta/meta.dart';

@immutable
final class RecoverBullTorSettings {
  final bool useTorProxy;
  final int torProxyPort;

  const RecoverBullTorSettings({
    required this.useTorProxy,
    required this.torProxyPort,
  });
}
