import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';

/// Validates a blindbit / electrum URL by actually connecting (standalone, no
/// live SP session). Orchestration only: the connect + try/catch lives in the
/// probe. The failure's `logMessage` carries the raw reason, never shown
/// to the user.
class TestSpBackendUsecase {
  final SpBackendProbePort _probe;

  TestSpBackendUsecase({required this._probe});

  /// An onion URL is refused before the probe: connecting would resolve the
  /// hidden-service name through the system DNS.
  @useResult
  Future<Result<void, SpFailure>> execute(
    SpBackendKind kind,
    String url,
  ) async {
    if (SpBackendConfig.isOnionUrl(url)) {
      return const Err(
        SpBackendOnionUnsupported('SP backend URL is an onion host'),
      );
    }
    return _probe.testBackend(kind, url);
  }
}
