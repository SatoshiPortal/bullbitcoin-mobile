import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'coins_error.freezed.dart';

@freezed
sealed class CoinsError with _$CoinsError {
  /// Loading the wallet's UTXOs failed.
  const factory CoinsError.loadFailed() = LoadFailedCoinsError;

  /// Freezing one or more outpoints failed.
  const factory CoinsError.freezeFailed() = FreezeFailedCoinsError;

  /// Unfreezing one or more outpoints failed.
  const factory CoinsError.unfreezeFailed() = UnfreezeFailedCoinsError;

  /// Catch-all. Never surfaces the raw dev message to the user.
  const factory CoinsError.unexpected({required String message}) =
      UnexpectedCoinsError;

  const CoinsError._();

  /// Returns the localized, user-facing error message.
  String toTranslated(BuildContext context) => switch (this) {
    LoadFailedCoinsError() => context.loc.coinsErrorLoadFailed,
    FreezeFailedCoinsError() => context.loc.coinsErrorFreezeFailed,
    UnfreezeFailedCoinsError() => context.loc.coinsErrorUnfreezeFailed,
    UnexpectedCoinsError() => context.loc.coinsErrorUnexpected,
  };
}
