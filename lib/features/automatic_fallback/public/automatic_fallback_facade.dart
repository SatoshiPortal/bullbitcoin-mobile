import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_setup.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/ensure_automatic_fallback_address_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
export 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_setup.dart';

class AutomaticFallbackFacade {
  final Future<Result<AutomaticFallbackSetup, AutomaticFallbackFailure>>
  Function()
  _ensureReady;

  AutomaticFallbackFacade({required this._ensureReady});

  factory AutomaticFallbackFacade.fromUsecase(
    EnsureAutomaticFallbackAddressUsecase usecase,
  ) {
    return AutomaticFallbackFacade(ensureReady: usecase.execute);
  }

  @useResult
  Future<Result<AutomaticFallbackSetup, AutomaticFallbackFailure>>
  ensureReady() => _ensureReady();
}
