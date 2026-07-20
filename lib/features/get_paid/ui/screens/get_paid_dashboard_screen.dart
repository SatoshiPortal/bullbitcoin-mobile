import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_routes.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/ui/fiat_settlement_copy.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_state.dart';
import 'package:bb_mobile/features/get_paid/public/get_paid_routes.dart';
import 'package:bb_mobile/features/get_paid/ui/widgets/get_paid_slot_card.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_routes.dart';
import 'package:bb_mobile/features/invoices/public/invoices_routes.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_routes.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_routes.dart';
import 'package:bb_mobile/features/pos/public/pos_routes.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart'
    show
        AppLifecycleState,
        Icons,
        SliverChildListDelegate,
        SliverList,
        SliverPadding,
        WidgetsBinding,
        WidgetsBindingObserver;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Get Paid hub — the third bottom-nav tab. Draws its own [BullTopBar]
/// (the shell app bar is null for this tab) and lists Get Paid history plus the
/// products as tappable slot cards. Auto-refreshes on init, on app-resume and
/// on pull; reads public facades only.
class GetPaidDashboardScreen extends StatefulWidget {
  const GetPaidDashboardScreen({super.key});

  @override
  State<GetPaidDashboardScreen> createState() => _GetPaidDashboardScreenState();
}

class _GetPaidDashboardScreenState extends State<GetPaidDashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<GetPaidDashboardCubit>().refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<GetPaidDashboardCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.getPaidDashboardTitle,
              onAction: () =>
                  context.pushNamed(GetPaidSettingsRoute.getPaidSettings.name),
              actionIcon: Icons.settings,
            ),
            Expanded(
              child: BlocConsumer<GetPaidDashboardCubit, GetPaidDashboardState>(
                listenWhen: (prev, curr) =>
                    prev.error != curr.error && curr.error != null,
                listener: (context, state) {
                  BullSnackBar.show(
                    context,
                    message: context.loc.getPaidDashboardError,
                  );
                },
                builder: (context, state) {
                  return BullPullableBody(
                    onRefresh: context.read<GetPaidDashboardCubit>().refresh,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            _cards(context, state),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cards(BuildContext context, GetPaidDashboardState state) {
    final loc = context.loc;
    final page = state.paymentPage;
    final pos = state.posTerminal;
    return [
      GetPaidSlotCard(
        icon: Icons.payments_outlined,
        title: loc.getPaidDashboardTransactionsTitle,
        subtitle: loc.getPaidDashboardTransactionsSubtitle,
        onTap: () => _open(GetPaidDashboardRoute.getPaidTransactions.name),
      ),
      const Gap(12),
      GetPaidSlotCard(
        icon: Icons.alternate_email,
        title: loc.getPaidDashboardLightningAddressTitle,
        // Show the address as the subtitle whenever one is present, regardless
        // of the active status (the status dot reflects `active` separately).
        subtitle: _withSettlementSummary(
          context,
          state,
          FiatSettlementProduct.lightningAddress,
          active: state.lightningActive,
          base: state.hasLightningAddress
              ? state.lightningAddress!
              : loc.getPaidDashboardLightningAddressSubtitle,
        ),
        isLoading: state.lightningStatus == GetPaidDashboardCardStatus.loading,
        // Active green when the registration itself is ACTIVE.
        statusLabel: state.lightningActive ? loc.getPaidDashboardActive : null,
        statusActive: state.lightningActive,
        onTap: () => _open(LightningAddressRoute.lightningAddressSettings.name),
      ),
      const Gap(12),
      GetPaidSlotCard(
        icon: Icons.storefront,
        title: loc.getPaidDashboardDonationPageTitle,
        subtitle: _withSettlementSummary(
          context,
          state,
          FiatSettlementProduct.paymentPage,
          active: state.hasPaymentPage,
          base: page?.publicUrl ?? loc.getPaidDashboardDonationPageSubtitle,
        ),
        isLoading:
            state.paymentPageStatus == GetPaidDashboardCardStatus.loading,
        // Active green when a (non-archived) payment page exists.
        statusLabel: state.hasPaymentPage ? loc.getPaidDashboardActive : null,
        statusActive: state.hasPaymentPage,
        onTap: () => _open(PaymentPageRoute.paymentPageSettings.name),
      ),
      const Gap(12),
      GetPaidSlotCard(
        icon: Icons.point_of_sale,
        title: loc.getPaidDashboardPosTitle,
        subtitle: _withSettlementSummary(
          context,
          state,
          FiatSettlementProduct.pos,
          active: state.hasPos,
          base: pos?.terminalUrl ?? loc.getPaidDashboardPosSubtitle,
        ),
        isLoading: state.posStatus == GetPaidDashboardCardStatus.loading,
        // Active green when a (non-archived) POS terminal exists.
        statusLabel: state.hasPos ? loc.getPaidDashboardActive : null,
        statusActive: state.hasPos,
        onTap: () => _open(PosRoute.posSettings.name),
      ),
      const Gap(12),
      GetPaidSlotCard(
        icon: Icons.receipt_long,
        title: loc.getPaidDashboardInvoicesTitle,
        subtitle: _withSettlementSummary(
          context,
          state,
          FiatSettlementProduct.invoice,
          active: state.invoicesWalletReady,
          base: loc.getPaidDashboardInvoicesSubtitle,
        ),
        isLoading: state.invoicesStatus == GetPaidDashboardCardStatus.loading,
        // Active green once the user's default wallet is created (invoices pay
        // out from the default wallet).
        statusLabel: state.hasFallbackAttention
            ? loc.getPaidDashboardFallbackPending(state.fallbackAttentionCount!)
            : state.invoicesWalletReady
            ? loc.getPaidDashboardActive
            : null,
        statusActive: state.invoicesWalletReady && !state.hasFallbackAttention,
        onTap: () => _open(InvoicesRoute.create.name),
      ),
      const Gap(12),
      GetPaidSlotCard(
        icon: Icons.hub,
        title: loc.getPaidDashboardBtcpayTitle,
        // No store-name field on the connection; the server URL is the most
        // human-readable identifier available.
        subtitle:
            state.btcpayConnection?.serverUrl ??
            loc.getPaidDashboardBtcpaySubtitle,
        isLoading: state.btcpayStatus == GetPaidDashboardCardStatus.loading,
        // Active green when a BTCPay connection exists.
        statusLabel: state.hasBtcpayConnection
            ? loc.getPaidDashboardActive
            : null,
        statusActive: state.hasBtcpayConnection,
        onTap: () => _open(BtcpayRoute.btcpaySettings.name),
      ),
    ];
  }

  /// Appends the saved settlement summary to an ACTIVE product slot's subtitle.
  /// Inactive slots, and any environment where the map is unavailable (testnet
  /// / tolerant read miss), are left unchanged.
  String _withSettlementSummary(
    BuildContext context,
    GetPaidDashboardState state,
    FiatSettlementProduct product, {
    required bool active,
    required String base,
  }) {
    if (!active) return base;
    final config = state.fiatSettlement?[product];
    if (config == null) return base;
    return '$base\n${context.fiatSettlementSummary(config)}';
  }

  Future<void> _open(String routeName) async {
    // Each product's screen resolves create-vs-manage internally (single-route
    // model on this base); the hub just returns and re-reads status.
    await context.pushNamed(routeName);
    if (!mounted) return;
    await context.read<GetPaidDashboardCubit>().refresh();
  }
}
