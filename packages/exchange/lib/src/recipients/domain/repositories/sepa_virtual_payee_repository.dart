import 'package:primitives/primitives.dart';
import 'package:exchange/src/domain/exchange_failure.dart';
import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:meta/meta.dart';

/// The virtual payee lets a SEPA recipient receive Confidential SEPA payouts.
abstract interface class SepaVirtualPayeeRepository {
  @useResult
  Future<Result<SepaVirtualPayeeStatus, ExchangeFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  });

  /// Returns `null` when the user has no SEPA recipient with [recipientId].
  @useResult
  Future<Result<SepaVirtualPayeeStatus?, ExchangeFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  });
}
