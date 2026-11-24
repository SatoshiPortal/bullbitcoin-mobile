import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';

/// The API reports no status until a virtual payee exists, and `ACTIVE` once
/// it can receive payouts. Any other value means activation is in progress.
SepaVirtualPayeeStatus sepaVirtualPayeeStatusFromApi(String? value) =>
    switch (value?.toUpperCase()) {
      null => SepaVirtualPayeeStatus.absent,
      'ACTIVE' => SepaVirtualPayeeStatus.active,
      _ => SepaVirtualPayeeStatus.pending,
    };
