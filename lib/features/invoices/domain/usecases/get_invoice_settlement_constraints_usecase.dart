import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';

class InvoiceSettlementConstraints {
  final bool directLiquidAvailable;

  const InvoiceSettlementConstraints({required this.directLiquidAvailable});
}

/// Maps the saved invoice settlement mode into payer-facing rail constraints.
class GetInvoiceSettlementConstraintsUsecase {
  final FiatSettlementFacade _fiatSettlement;

  const GetInvoiceSettlementConstraintsUsecase(this._fiatSettlement);

  Future<InvoiceSettlementConstraints?> execute() async {
    final result = await _fiatSettlement.configuration();
    return switch (result) {
      Ok(:final value) => InvoiceSettlementConstraints(
        directLiquidAvailable:
            value.configFor(FiatSettlementProduct.invoice).mode !=
            FiatSettlementMode.mixed,
      ),
      Err() => null,
    };
  }
}
