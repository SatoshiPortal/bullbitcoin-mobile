import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Hands a saved or picked recipient to the feature that opened the
/// recipients screen (`pay`, `withdraw`), if it asked for it.
///
/// The one place recipients catch. The hook is a callback owned by the
/// calling feature, so it sits outside this feature's Result contract and
/// can throw; catching it here, at the boundary with that foreign code,
/// keeps the machine free of error handling. Making the hook return a
/// Result instead would remove this catch, but its signature belongs to the
/// calling features.
class RunRecipientSelectionUsecase {
  final Future<void>? Function(
    RecipientViewModel recipient, {
    required bool isNew,
  })?
  _hook;

  const RunRecipientSelectionUsecase(this._hook);

  Future<Result<void, ExchangeRecipientsSelectionFailure>> execute(
    RecipientViewModel recipient, {
    required bool isNew,
  }) async {
    final hook = _hook;
    if (hook == null) return const Ok(null);
    try {
      await hook(recipient, isNew: isNew);
      return const Ok(null);
    } on Object catch (e, st) {
      log.warning('Recipient selection hook failed', error: e, trace: st);
      return const Err(ExchangeRecipientsSelectionFailure());
    }
  }
}
