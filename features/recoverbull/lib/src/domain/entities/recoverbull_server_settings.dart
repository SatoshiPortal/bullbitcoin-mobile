import 'package:meta/meta.dart';

@immutable
final class RecoverBullServerSettings {
  final Uri server;
  final bool permissionGranted;

  const RecoverBullServerSettings({
    required this.server,
    required this.permissionGranted,
  });
}
