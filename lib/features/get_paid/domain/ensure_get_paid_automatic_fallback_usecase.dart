import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/public/automatic_fallback_facade.dart';

/// Invokes the automatic-fallback feature without leaking its failure family
/// into Get Paid presentation state.
///
/// Setup is a prerequisite for a complete Get Paid snapshot, but a failure
/// must not hide the other independently supervised products.
class EnsureGetPaidAutomaticFallbackUsecase {
  final AutomaticFallbackFacade _automaticFallback;

  const EnsureGetPaidAutomaticFallbackUsecase({
    required this._automaticFallback,
  });

  Future<bool> execute() async {
    final result = await _automaticFallback.ensureReady();
    return switch (result) {
      Ok() => true,
      Err(:final failure) => _reportUnavailable(
        kind: failure.kind.name,
        code: failure.code,
      ),
    };
  }

  bool _reportUnavailable({required String kind, required String code}) {
    log.warning(
      'Get Paid automatic fallback setup is unavailable',
      error: '$kind:$code',
    );
    return false;
  }
}
