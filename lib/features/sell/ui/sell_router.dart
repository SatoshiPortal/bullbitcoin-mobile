import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/recipients/public/recipients_ui.dart';
import 'package:bb_mobile/features/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase_v2.dart';
import 'package:bb_mobile/features/sell/domain/sell_payin_source_v2.dart';
import 'package:bb_mobile/features/sell/presentation/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_payout_cubit_v2.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_external_wallet_network_selection_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_payout_method_screen_v2.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_receive_payment_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_send_payment_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_success_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_wallet_selection_screen.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_payout_route_guard_v2.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show SizedBox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SellRoute {
  sell('/sell'),
  sellWalletSelection('wallet-selection'),
  sellPayoutV2('eur-payout-v2'),
  sellRecipientsV2('eur-recipients-v2'),
  sellVirtualIbanV2('eur-virtual-iban-v2'),
  sellVirtualPayeeV2('eur-virtual-payee-v2'),
  sellExternalWalletNetworkSelection('external-wallet-network-selection'),
  sellExternalWalletReceivePayment('external-wallet-receive-payment'),
  sellSendPayment('send-payment'),
  sellSuccess('success');

  final String path;

  const SellRoute(this.path);
}

class SellRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (_) => locator<SellBloc>()..add(const SellEvent.started()),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: SellRoute.sell.name,
        path: SellRoute.sell.path,
        redirect: (context, state) {
          final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
          if (notLoggedIn) return ExchangeRoute.exchangeHome.path;
          return null;
        },
        builder: (context, state) => BlocListener<SellBloc, SellState>(
          listenWhen: (previous, current) =>
              previous is SellAmountInputState &&
              current is SellWalletSelectionState,
          listener: (context, state) {
            context.pushNamed(SellRoute.sellWalletSelection.name);
          },
          child: const SellScreen(),
        ),
        routes: [
          GoRoute(
            name: SellRoute.sellWalletSelection.name,
            path: SellRoute.sellWalletSelection.path,
            builder: (context, state) => BlocListener<SellBloc, SellState>(
              listenWhen: (previous, current) =>
                  current is SellPreparingPaymentState &&
                  previous is! SellPreparingPaymentState &&
                  current.fiatCurrency != FiatCurrency.eur &&
                  current.selectedWallet != null,
              listener: (context, state) {
                context.pushNamed(SellRoute.sellSendPayment.name);
              },
              child: const SellWalletSelectionScreen(),
            ),
          ),
          GoRoute(
            name: SellRoute.sellPayoutV2.name,
            path: SellRoute.sellPayoutV2.path,
            builder: (context, state) {
              final source = state.extra;
              if (source is! SellPayinSourceV2) {
                return const SellPayoutRouteGuardV2(
                  hasValidArguments: false,
                  child: SizedBox.shrink(),
                );
              }
              return SellPayoutRouteGuardV2(
                child: BlocProvider(
                  create: (_) => SellPayoutCubitV2(
                    locator<GetSellConfidentialSepaAvailabilityUsecaseV2>(),
                  )..load(),
                  child: BlocListener<SellBloc, SellState>(
                    listenWhen: (previous, current) =>
                        previous is SellPreparingPaymentState &&
                        current is SellPaymentState,
                    listener: (context, state) {
                      if (state is SellPaymentState) {
                        context.pushNamed(
                          state.selectedWallet == null
                              ? SellRoute.sellExternalWalletReceivePayment.name
                              : SellRoute.sellSendPayment.name,
                        );
                      }
                    },
                    child: SellPayoutMethodScreenV2(source: source),
                  ),
                ),
              );
            },
          ),
          GoRoute(
            name: SellRoute.sellRecipientsV2.name,
            path: SellRoute.sellRecipientsV2.path,
            builder: (context, state) => SellPayoutRouteGuardV2(
              hasValidArguments:
                  state.extra == RecipientType.sepaEur ||
                  state.extra == RecipientType.confidentialSepaEur,
              child: RecipientSelectionScreenV2(
                isConfidential:
                    state.extra == RecipientType.confidentialSepaEur,
              ),
            ),
          ),
          GoRoute(
            name: SellRoute.sellVirtualIbanV2.name,
            path: SellRoute.sellVirtualIbanV2.path,
            builder: (context, state) => SellPayoutRouteGuardV2(
              child: VirtualIbanOnboardingScreen(
                onActivated: () =>
                    context.pop(RecipientType.confidentialSepaEur),
                onUseRegularSepa: () => context.pop(RecipientType.sepaEur),
                onReturnHome: () =>
                    context.goNamed(WalletRoute.walletHome.name),
              ),
            ),
          ),
          GoRoute(
            name: SellRoute.sellVirtualPayeeV2.name,
            path: SellRoute.sellVirtualPayeeV2.path,
            builder: (context, state) {
              final recipientId = state.extra;
              if (recipientId is! String || recipientId.trim().isEmpty) {
                return const SellPayoutRouteGuardV2(
                  hasValidArguments: false,
                  child: SizedBox.shrink(),
                );
              }
              return SellPayoutRouteGuardV2(
                child: SepaVirtualPayeeActivationScreen(
                  recipientId: recipientId,
                  onActivated: () =>
                      context.pop(RecipientType.confidentialSepaEur),
                  onUseRegularSepa: () => context.pop(RecipientType.sepaEur),
                  onReturnHome: () =>
                      context.goNamed(WalletRoute.walletHome.name),
                ),
              );
            },
          ),
          GoRoute(
            name: SellRoute.sellSendPayment.name,
            path: SellRoute.sellSendPayment.path,
            builder: (context, state) => BlocListener<SellBloc, SellState>(
              listenWhen: (previous, current) =>
                  previous is SellPaymentState && current is SellSuccessState,
              listener: (context, state) {
                context.pushNamed(SellRoute.sellSuccess.name);
              },
              child: const SellSendPaymentScreen(),
            ),
          ),
          GoRoute(
            name: SellRoute.sellExternalWalletNetworkSelection.name,
            path: SellRoute.sellExternalWalletNetworkSelection.path,
            builder: (context, state) => BlocListener<SellBloc, SellState>(
              listenWhen: (previous, current) =>
                  current is SellPreparingPaymentState &&
                  previous is! SellPreparingPaymentState &&
                  current.fiatCurrency != FiatCurrency.eur &&
                  current.selectedWallet == null,
              listener: (context, state) {
                context.pushNamed(
                  SellRoute.sellExternalWalletReceivePayment.name,
                );
              },
              child: const SellExternalWalletNetworkSelectionScreen(),
            ),
          ),
          GoRoute(
            name: SellRoute.sellExternalWalletReceivePayment.name,
            path: SellRoute.sellExternalWalletReceivePayment.path,
            builder: (context, state) => BlocListener<SellBloc, SellState>(
              listenWhen: (previous, current) =>
                  previous is SellPaymentState && current is SellSuccessState,
              listener: (context, state) {
                context.pushNamed(SellRoute.sellSuccess.name);
              },
              child: const SellReceivePaymentScreen(),
            ),
          ),
          GoRoute(
            name: SellRoute.sellSuccess.name,
            path: SellRoute.sellSuccess.path,
            builder: (context, state) => const SellSuccessScreen(),
          ),
        ],
      ),
    ],
  );
}
