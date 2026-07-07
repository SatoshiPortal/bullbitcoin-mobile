import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:get_it/get_it.dart';

/// Wires the Get Paid hub. The dashboard cubit reads the public facades only;
/// it must be registered after btcpay/lightning_address/payment_page/pos.
class GetPaidLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<GetPaidDashboardCubit>(
      () => GetPaidDashboardCubit(
        lightningAddress: locator<LightningAddressFacade>(),
        paymentPage: locator<PaymentPageFacade>(),
        pos: locator<PosFacade>(),
        btcpay: locator<BtcpayFacade>(),
      ),
    );
  }
}
