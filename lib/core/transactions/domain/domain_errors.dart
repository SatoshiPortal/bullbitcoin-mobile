import 'package:freezed_annotation/freezed_annotation.dart';

part 'domain_errors.freezed.dart';

/// Errors thrown by implementations of [TransactionPort].
///
/// Port-layer concerns only — fetching a parsed transaction from an
/// external source. Higher layers map these into their own domain errors
/// at the boundary so the port's error type never leaks upward.
@freezed
sealed class TransactionPortError with _$TransactionPortError {
  /// Failed to fetch the transaction across all configured servers.
  const factory TransactionPortError.fetchFailed({
    required String txid,
    String? message,
  }) = TransactionPortFetchFailed;

  /// No servers are available for the requested network.
  const factory TransactionPortError.noServersAvailable({String? network}) =
      TransactionPortNoServersAvailable;

  const TransactionPortError._();
}
