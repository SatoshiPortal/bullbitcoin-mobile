import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart';
import 'package:bull_exchange/src/sell/domain/sell_payin_source.dart';
import 'package:bull_exchange/src/sell/presentation/sell_bloc.dart';
import 'package:bull_exchange/src/sell/presentation/sell_payout_cubit.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_external_wallet_network_selection_screen.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_payout_method_screen.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_receive_payment_screen.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_screen.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_send_payment_screen.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_success_screen.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_wallet_selection_screen.dart';
import 'package:bull_exchange/src/sell/ui/widgets/sell_payout_route_guard.dart';
import 'package:bull_ui/bull_ui.dart' show SizedBox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SellRoute {
  sell('/sell'),
  sellWalletSelection('wallet-selection'),
  sellPayout('payout'),
  sellRecipients('payout-recipients'),
  sellVirtualIban('payout-virtual-iban'),
  sellVirtualPayee('payout-virtual-payee'),
  sellExternalWalletNetworkSelection('external-wallet-network-selection'),
  sellExternalWalletReceivePayment('external-wallet-receive-payment'),
  sellSendPayment('send-payment'),
  sellSuccess('success');

  final String path;

  const SellRoute(this.path);
}

class SellRouter {
  static ShellRoute route({
    required SellBloc Function() createBloc,
    required GetSellConfidentialSepaAvailabilityUsecase Function() availability,
    required ExchangePayinUi ui,
  }) => ShellRoute(
    builder: (context, state, child) {
      return RepositoryProvider.value(
        value: ui,
        child: BlocProvider(
          create: (_) => createBloc()..add(const SellEvent.started()),
          child: child,
        ),
      );
    },
    routes: [
      GoRoute(
        name: SellRoute.sell.name,
        path: SellRoute.sell.path,
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
            builder: (context, state) => const SellWalletSelectionScreen(),
          ),
          GoRoute(
            name: SellRoute.sellPayout.name,
            path: SellRoute.sellPayout.path,
            builder: (context, state) {
              final source = state.extra;
              if (source is! SellPayinSource) {
                return const SellPayoutRouteGuard(
                  hasValidArguments: false,
                  child: SizedBox.shrink(),
                );
              }
              return SellPayoutRouteGuard(
                child: BlocProvider(
                  create: (_) =>
                      SellPayoutCubit(availability())
                        ..load(context.read<SellBloc>().state.fiatCurrency),
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
                    child: SellPayoutMethodScreen(source: source),
                  ),
                ),
              );
            },
          ),
          GoRoute(
            name: SellRoute.sellRecipients.name,
            path: SellRoute.sellRecipients.path,
            builder: (context, state) {
              final type = state.extra;
              if (type is! RecipientType) {
                return const SellPayoutRouteGuard(
                  hasValidArguments: false,
                  child: SizedBox.shrink(),
                );
              }
              return SellPayoutRouteGuard(
                hasValidArguments:
                    type.currencyCode ==
                    context.read<SellBloc>().state.fiatCurrency.code,
                child: RecipientSelectionScreen.returning(
                  types: [type],
                  isOwner: true,
                ),
              );
            },
          ),
          GoRoute(
            name: SellRoute.sellVirtualIban.name,
            path: SellRoute.sellVirtualIban.path,
            builder: (context, state) => SellPayoutRouteGuard(
              child: VirtualIbanOnboardingScreen(
                onActivated: () =>
                    context.pop(RecipientType.confidentialSepaEur),
                onUseRegularSepa: () => context.pop(RecipientType.sepaEur),
                onReturnHome: () => ui.openWalletHome(context),
              ),
            ),
          ),
          GoRoute(
            name: SellRoute.sellVirtualPayee.name,
            path: SellRoute.sellVirtualPayee.path,
            builder: (context, state) {
              final recipientId = state.extra;
              if (recipientId is! String || recipientId.trim().isEmpty) {
                return const SellPayoutRouteGuard(
                  hasValidArguments: false,
                  child: SizedBox.shrink(),
                );
              }
              return SellPayoutRouteGuard(
                child: SepaVirtualPayeeActivationScreen(
                  recipientId: recipientId,
                  onActivated: () =>
                      context.pop(RecipientType.confidentialSepaEur),
                  onUseRegularSepa: () => context.pop(RecipientType.sepaEur),
                  onReturnHome: () => ui.openWalletHome(context),
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
            builder: (context, state) =>
                const SellExternalWalletNetworkSelectionScreen(),
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
