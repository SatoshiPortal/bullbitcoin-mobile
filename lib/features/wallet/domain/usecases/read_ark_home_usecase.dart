import 'package:ark/ark.dart';

/// The host supplies a read-only observation; this never opens Ark.
final class ReadArkHomeUsecase {
  final Future<ArkSnapshot?> Function() _observe;
  const ReadArkHomeUsecase(this._observe);

  Future<ArkSnapshot?> execute() => _observe();
}
