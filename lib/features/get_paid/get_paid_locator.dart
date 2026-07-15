import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/public/automatic_fallback_facade.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/get_paid/domain/ensure_get_paid_automatic_fallback_usecase.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:get_it/get_it.dart';

/// Wires the Get Paid hub after all product facades and automatic fallback.
class GetPaidLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<EnsureGetPaidAutomaticFallbackUsecase>(
      () => EnsureGetPaidAutomaticFallbackUsecase(
        automaticFallback: locator<AutomaticFallbackFacade>(),
      ),
    );
    locator.registerFactory<GetPaidDashboardCubit>(
      () => GetPaidDashboardCubit(
        lightningAddress: locator<LightningAddressFacade>(),
        paymentPage: locator<PaymentPageFacade>(),
        pos: locator<PosFacade>(),
        btcpay: locator<BtcpayFacade>(),
        getWallets: locator<GetWalletsUsecase>(),
        ensureAutomaticFallback:
            locator<EnsureGetPaidAutomaticFallbackUsecase>(),
      ),
    );
  }
}
