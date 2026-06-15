import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Closed set of every failure the broadcast flow surfaces to the user.
///
/// Replaces the previous `errors.dart` `BullException` subclasses, whose
/// hardcoded English `message`s were rendered straight into the UI. Foreign
/// errors (BDK, Electrum, NFC parsing) are mapped into one of these variants at
/// the layer that owns the call; the raw reason stays in the logs.
///
/// `sealed` keeps it closed (no foreign variants; exhaustive switches). The
/// abstract `toTranslated` makes a user-facing message mandatory and keeps it
/// next to its variant.
sealed class BroadcastSignedTxError {
  const BroadcastSignedTxError();

  /// Localized, user-safe message. Never returns raw/technical detail.
  String toTranslated(BuildContext context);
}

final class InvalidTransactionError extends BroadcastSignedTxError {
  const InvalidTransactionError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.broadcastSignedTxErrorInvalidTransaction;
}

final class InvalidPushTxError extends BroadcastSignedTxError {
  const InvalidPushTxError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.broadcastSignedTxErrorInvalidPushTx;
}

final class BroadcastFailedError extends BroadcastSignedTxError {
  const BroadcastFailedError();

  @override
  String toTranslated(BuildContext context) =>
      context.loc.broadcastSignedTxBroadcastError;
}

/// Catch-all. [message] is for logs only and MUST never reach the UI —
/// `toTranslated` returns the shared generic string, not [message].
final class UnexpectedBroadcastError extends BroadcastSignedTxError {
  final String message;

  const UnexpectedBroadcastError(this.message);

  @override
  String toTranslated(BuildContext context) =>
      context.loc.oopsSomethingWentWrong;
}
