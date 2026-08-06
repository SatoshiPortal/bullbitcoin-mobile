import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class StoreRecoverbullUrlUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreRecoverbullUrlUsecase({required this._recoverBullRepository});

  Future<void> execute(Uri url) async {
    // The key-server URL scopes every telemetry row: identifiers and
    // snapshots from different servers are unrelated, so changing the URL
    // invalidates the old server's baseline (ETag, counters, wipe marker).
    try {
      final previous = await _recoverBullRepository.fetchUrl();
      if (previous != url) {
        await _recoverBullRepository.deleteTelemetryForServer(
          previous.toString(),
        );
      }
    } catch (_) {
      // no previous URL stored yet: nothing to invalidate
    }
    await _recoverBullRepository.storeUrl(url);
  }
}
