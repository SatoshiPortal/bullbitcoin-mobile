import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/public/automatic_fallback_facade.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid/domain/ensure_get_paid_automatic_fallback_usecase.dart';
import 'package:bb_mobile/features/get_paid/data/get_paid_default_wallet_xprv_adapter.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_fallback_attention_usecase.dart';
import 'package:bb_mobile/features/get_paid/domain/list_get_paid_transactions_usecase.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

/// Wires the Get Paid hub after all product facades and automatic fallback.
class GetPaidLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<EnsureGetPaidAutomaticFallbackUsecase>(
      () => EnsureGetPaidAutomaticFallbackUsecase(
        automaticFallback: locator<AutomaticFallbackFacade>(),
      ),
    );
    locator.registerFactory<GetPaidFallbackAttentionUsecase>(
      () =>
          GetPaidFallbackAttentionUsecase(invoices: locator<InvoicesFacade>()),
    );
    locator.registerFactory<GetPaidDefaultWalletXprvPort>(
      () => GetPaidDefaultWalletXprvAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<ListGetPaidTransactionsUsecase>(
      () => ListGetPaidTransactionsUsecase(
        defaultWalletXprv: locator<GetPaidDefaultWalletXprvPort>(),
        bullnym: locator<BullnymFacade>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
      ),
    );
    locator.registerFactory<GetPaidTransactionHistoryCubit>(
      () => GetPaidTransactionHistoryCubit(
        listTransactions: locator<ListGetPaidTransactionsUsecase>(),
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
        fallbackAttention: locator<GetPaidFallbackAttentionUsecase>(),
      ),
    );
  }
}
