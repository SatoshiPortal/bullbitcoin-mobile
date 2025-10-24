import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:bb_mobile/features/ark/ui/ark_about_page.dart';
import 'package:bb_mobile/features/ark/ui/ark_transaction_details_page.dart';
import 'package:bb_mobile/features/ark/ui/ark_wallet_detail_page.dart';
import 'package:bb_mobile/features/ark/ui/receive_page.dart';
import 'package:bb_mobile/features/ark/ui/send_amount_page.dart';
import 'package:bb_mobile/features/ark/ui/send_confirm_page.dart';
import 'package:bb_mobile/features/ark/ui/send_recipient_page.dart';
import 'package:bb_mobile/features/ark/ui/send_success_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ArkRoute {
  arkWalletDetail('/ark-wallet-detail'),
  arkAbout('/ark-about'),
  arkTransactionDetails('/ark-transaction-details'),
  arkReceive('/ark-receive'),
  arkSendRecipient('/ark-send'),
  arkSendAmount('/ark-send/amount'),
  arkSendConfirm('/ark-send/confirm'),
  arkSendSuccess('/ark-send/success');

  final String path;

  const ArkRoute(this.path);
}

class ArkRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      final wallet = context.watch<WalletBloc>().state.arkWallet;

      if (wallet == null) {
        log.severe('Ark needs an ark wallet initialized');
        throw ArkWalletIsNotInitializedError();
      }

      return BlocProvider(
        create:
            // TODO: move the ArkCubit DI to locator
            (context) => ArkCubit(
              wallet: wallet,
              convertSatsToCurrencyAmountUsecase:
                  locator<ConvertSatsToCurrencyAmountUsecase>(),
              getAvailableCurrenciesUsecase:
                  locator<GetAvailableCurrenciesUsecase>(),
              getSettingsUsecase: locator<GetSettingsUsecase>(),
              walletBloc: context.read<WalletBloc>(),
            )..load(),

        child: child,
      );
    },
    routes: [
      GoRoute(
        name: ArkRoute.arkWalletDetail.name,
        path: ArkRoute.arkWalletDetail.path,
        builder: (context, state) => const ArkWalletDetailPage(),
      ),
      GoRoute(
        name: ArkRoute.arkAbout.name,
        path: ArkRoute.arkAbout.path,
        builder: (context, state) => const ArkAboutPage(),
      ),
      GoRoute(
        name: ArkRoute.arkTransactionDetails.name,
        path: ArkRoute.arkTransactionDetails.path,
        builder: (context, state) {
          final transaction = state.extra! as ark_wallet.Transaction;
          return ArkTransactionDetailsPage(transaction: transaction);
        },
      ),
      GoRoute(
        name: ArkRoute.arkReceive.name,
        path: ArkRoute.arkReceive.path,
        builder: (context, state) => const ReceivePage(),
      ),
      GoRoute(
        name: ArkRoute.arkSendRecipient.name,
        path: ArkRoute.arkSendRecipient.path,
        builder: (context, state) {
          final prefilledRecipient = state.uri.queryParameters['recipient'];
          final prefilledAmount = state.uri.queryParameters['amount'];
          final prefilledCurrencyCode =
              state.uri.queryParameters['currencyCode'];
          return BlocListener<ArkCubit, ArkState>(
            listenWhen:
                (previous, current) =>
                    previous.sendAddress == null && current.sendAddress != null,
            listener: (BuildContext context, ArkState state) {
              context.pushNamed(
                ArkRoute.arkSendAmount.name,
                queryParameters: {
                  if (prefilledAmount != null) 'amount': prefilledAmount,
                  if (prefilledCurrencyCode != null)
                    'currencyCode': prefilledCurrencyCode,
                },
              );
            },
            child: SendRecipientPage(prefilledRecipient: prefilledRecipient),
          );
        },
      ),
      GoRoute(
        name: ArkRoute.arkSendAmount.name,
        path: ArkRoute.arkSendAmount.path,
        builder: (context, state) {
          final prefilledAmount = state.uri.queryParameters['amount'];
          final prefilledCurrencyCode =
              state.uri.queryParameters['currencyCode'];
          return BlocListener<ArkCubit, ArkState>(
            listenWhen:
                (previous, current) =>
                    previous.amountSat == null && current.amountSat != null,
            listener: (BuildContext context, ArkState state) {
              context.pushNamed(ArkRoute.arkSendConfirm.name);
            },
            child: SendAmountPage(
              prefilledAmount: prefilledAmount,
              prefilledCurrencyCode: prefilledCurrencyCode,
            ),
          );
        },
      ),
      GoRoute(
        name: ArkRoute.arkSendConfirm.name,
        path: ArkRoute.arkSendConfirm.path,
        builder:
            (context, state) => BlocListener<ArkCubit, ArkState>(
              listenWhen:
                  (previous, current) =>
                      previous.txid.isEmpty && current.txid.isNotEmpty,
              listener: (BuildContext context, ArkState state) {
                context.goNamed(ArkRoute.arkSendSuccess.name);
              },
              child: const SendConfirmPage(),
            ),
      ),
      GoRoute(
        name: ArkRoute.arkSendSuccess.name,
        path: ArkRoute.arkSendSuccess.path,
        builder: (context, state) => const SendSuccessPage(),
      ),
    ],
  );
}
