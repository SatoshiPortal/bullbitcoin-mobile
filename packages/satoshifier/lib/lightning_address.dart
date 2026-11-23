import 'package:primitives/primitives.dart';
import 'package:rust_bindings/boltz.dart';

import 'payment_request.dart';

sealed class LightningAddressFailure extends Failure {
  const LightningAddressFailure();
}

final class InvalidLightningAddressInvoice extends LightningAddressFailure {
  const InvalidLightningAddressInvoice();
}

final class LightningAddressUnavailable extends LightningAddressFailure {
  const LightningAddressUnavailable();
}

/// Resolves a Lightning address to an invoice for the requested amount.
Future<Result<Bolt11PaymentRequest, LightningAddressFailure>>
resolveLightningAddress(String address, Sats amount) async {
  if (amount.value <= BigInt.zero) {
    return const Err(InvalidLightningAddressInvoice());
  }
  try {
    final invoice = await Lnurl(value: address)
        .fetchInvoice(msats: amount.value * BigInt.from(1000));
    final request = await PaymentRequest.parse(invoice.toLowerCase());
    return switch (request) {
      final Bolt11PaymentRequest request
          when BigInt.from(request.amountSat) == amount.value =>
        Ok(request),
      _ => const Err(InvalidLightningAddressInvoice()),
    };
  } on BoltzError {
    return const Err(LightningAddressUnavailable());
  } on Exception {
    return const Err(LightningAddressUnavailable());
  }
}
