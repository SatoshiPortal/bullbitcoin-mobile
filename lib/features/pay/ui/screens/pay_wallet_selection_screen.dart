import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class PayWalletSelectionScreen extends StatelessWidget {
  const PayWalletSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Update BitcoinPriceBloc currency to match pay flow currency
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currency = context.read<PayBloc>().state.currency;
      context.read<BitcoinPriceBloc>().add(
        BitcoinPriceCurrencyChanged(currencyCode: currency.code),
      );
    });
    final isCreatingPayOrder = context.select(
      (PayBloc bloc) =>
          bloc.state is PayWalletSelectionState &&
          (bloc.state as PayWalletSelectionState).isCreatingPayOrder,
    );

    final currency = context.select((PayBloc bloc) => bloc.state.currency);

    return BullPage(
      topBar: BullTopBar(
        title: context.loc.paySelectWallet,
        onBack: context.pop,
      ),
      safeArea: false,
      child: SafeArea(
        child: Column(
          children: [
            BullFadingLinearProgress(
              height: 3,
              trigger: isCreatingPayOrder,
              backgroundColor: context.appColors.onPrimary,
              foregroundColor: context.appColors.primary,
            ),
            Expanded(
              child: BullScrollableColumn(
                children: [
                  const Gap(24.0),
                  BullText(
                    context.loc.payWhichWallet,
                    style: context.bullText.labelMedium,
                  ),
                  const Gap(24.0),
                  WalletCards(
                    padding: EdgeInsets.zero,
                    onTap: isCreatingPayOrder
                        ? null
                        : (wallet) => context.read<PayBloc>().add(
                            PayEvent.walletSelected(wallet: wallet),
                          ),
                    localSignersOnly: true,
                    fiatCurrency: currency.code,
                  ),
                  const Gap(24.0),
                  BullBorderedTile(
                    onTap: isCreatingPayOrder
                        ? null
                        : () => context.pushNamed(
                            PayRoute.payExternalWalletNetworkSelection.name,
                            extra: context.read<PayBloc>(),
                          ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BullText(
                                context.loc.payExternalWallet,
                                style: context.bullText.bodyLarge,
                              ),
                              BullText(
                                context.loc.payExternalWalletDescription,
                                style: context.bullText.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  const Gap(24.0),
                  const _PayError(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayError extends StatelessWidget {
  const _PayError();

  @override
  Widget build(BuildContext context) {
    final payError = context.select(
      (PayBloc bloc) => bloc.state is PayWalletSelectionState
          ? (bloc.state as PayWalletSelectionState).error
          : null,
    );

    if (payError == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        payError.toTranslated(context),
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
