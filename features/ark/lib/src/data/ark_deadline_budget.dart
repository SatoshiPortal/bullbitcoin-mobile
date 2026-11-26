import 'package:ark/ark_setup.dart';

/// A deadline revokes the next stage, never the native call already admitted.
/// Native code retains writer ownership until that call settles.
final class ArkDeadlineBudget implements ArkStageBudget {
  final Duration limit;
  final Stopwatch _elapsed;
  bool _revoked = false;
  ArkDeadlineBudget(this.limit) : _elapsed = Stopwatch()..start() {
    if (limit.isNegative) throw ArgumentError('Negative Ark stage budget');
  }
  void revoke() {
    _revoked = true;
  }

  @override
  bool get mayAdmitNextStage => !_revoked && _elapsed.elapsed < limit;
}

/// Shares the dispatcher's original OS window, including headless bootstrap.
final class ArkBackgroundStageBudget implements ArkStageBudget {
  final bool Function() _admit;
  const ArkBackgroundStageBudget(this._admit);
  @override
  bool get mayAdmitNextStage => _admit();
}
