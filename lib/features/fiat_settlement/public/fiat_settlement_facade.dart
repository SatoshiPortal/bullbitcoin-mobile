import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/entities/fiat_settlement.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/disable_fiat_settlement_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/get_fiat_settlement_configuration_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/set_fiat_settlement_usecase.dart';

export 'package:bb_mobile/features/fiat_settlement/domain/entities/fiat_settlement.dart';
export 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';

/// The only cross-feature entry point into fiat settlement. Products call it to
/// probe capability, read configuration, and activate/change/disable settlement.
class FiatSettlementFacade {
  final GetFiatSettlementConfigurationUsecase _getConfiguration;
  final SetFiatSettlementUsecase _set;
  final DisableFiatSettlementUsecase _disable;

  const FiatSettlementFacade({
    required this._getConfiguration,
    required this._set,
    required this._disable,
  });

  Future<Result<FiatSettlementConfigurationView, FiatSettlementFailure>>
  configuration() => _getConfiguration.execute();

  Future<Result<FiatSettlementConfigurationView, FiatSettlementFailure>> set({
    required FiatSettlementProduct product,
    required int fiatPercentage,
    required FiatCurrency currency,
  }) => _set.execute(
    product: product,
    fiatPercentage: fiatPercentage,
    currency: currency,
  );

  Future<Result<FiatSettlementConfigurationView, FiatSettlementFailure>>
  disable({required FiatSettlementProduct product}) =>
      _disable.execute(product: product);

  @override
  String toString() => 'FiatSettlementFacade';
}
