import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';

/// The API reports no status until a virtual payee exists, and `ACTIVE` once
/// it can receive payouts. `CREATED` and `PROCESSING` (the values BBX's own
/// tests use) and `PENDING` mean activation is in progress. Any other value
/// is [SepaVirtualPayeeStatus.unknown], logged once; it used to read as
/// pending and was polled and re-activated forever (RCP-11).
SepaVirtualPayeeStatus sepaVirtualPayeeStatusFromApi(String? value) =>
    switch (value?.toUpperCase()) {
      null => SepaVirtualPayeeStatus.absent,
      'ACTIVE' => SepaVirtualPayeeStatus.active,
      'CREATED' || 'PROCESSING' || 'PENDING' => SepaVirtualPayeeStatus.pending,
      final String other => _unknown(other),
    };

SepaVirtualPayeeStatus _unknown(String raw) {
  UnknownServerValues.report('SEPA virtual payee status', raw);
  return SepaVirtualPayeeStatus.unknown;
}
