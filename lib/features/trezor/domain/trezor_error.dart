import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trezor_error.freezed.dart';

@freezed
sealed class TrezorError with _$TrezorError implements Exception {
  const factory TrezorError.userRejected() = TrezorUserRejected;
  const factory TrezorError.suiteNotInstalled() = TrezorSuiteNotInstalled;
  const factory TrezorError.suiteUnresponsive() = TrezorSuiteUnresponsive;
  const factory TrezorError.timeout() = TrezorTimeout;
  const factory TrezorError.addressMismatch({
    required String expected,
    required String returned,
  }) = TrezorAddressMismatch;
  const factory TrezorError.missingDescriptor() = TrezorMissingDescriptor;
  const factory TrezorError.unknown(String message) = TrezorUnknown;

  const TrezorError._();

  /// Returns the localized, user-safe message for this error.
  ///
  /// The [TrezorError.unknown] catch-all deliberately returns a generic
  /// localized string instead of the raw `message` — the raw text is for
  /// logs only (AGENTS.md rule #11: "the end user never sees a dev string").
  String toTranslated(BuildContext context) => switch (this) {
    TrezorUserRejected() => context.loc.trezorErrorUserRejected,
    TrezorSuiteNotInstalled() => context.loc.trezorErrorSuiteNotInstalled,
    TrezorSuiteUnresponsive() => context.loc.trezorErrorSuiteUnresponsive,
    TrezorTimeout() => context.loc.trezorErrorTimeout,
    TrezorAddressMismatch() => context.loc.trezorErrorAddressMismatch,
    TrezorMissingDescriptor() => context.loc.trezorErrorMissingDescriptor,
    TrezorUnknown() => context.loc.trezorErrorUnknown,
  };
}
