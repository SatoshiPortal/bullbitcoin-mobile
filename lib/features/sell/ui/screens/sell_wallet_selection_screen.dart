import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/sell/domain/sell_payin_source_v2.dart';
import 'package:bb_mobile/features/sell/presentation/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullScrollableColumn, Gap;
import 'package:go_router/go_router.dart';

class SellWalletSelectionScreen extends StatefulWidget {
  const SellWalletSelectionScreen({super.key});

  @override
  State<SellWalletSelectionScreen> createState() =>
      _SellWalletSelectionScreenState();
}

class _SellWalletSelectionScreenState extends State<SellWalletSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Show wallet values in the sell flow's currency. Once, on open: sent
    // from build, it went out again on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currency = context.read<SellBloc>().state.fiatCurrency;
      context.read<BitcoinPriceBloc>().add(
        BitcoinPriceCurrencyChanged(currencyCode: currency.code),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingSellOrder = context.select(
      (SellBloc bloc) => bloc.state is SellPreparingPaymentState,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.sellSelectWallet)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BullScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.sellWhichWalletQuestion,
                    style: context.font.labelMedium?.copyWith(
                      color: context.appColors.text,
                    ),
                  ),
                  const Gap(24.0),
                  WalletCards(
                    padding: EdgeInsets.zero,
                    onTap: isCreatingSellOrder
                        ? null
                        : (wallet) {
                            // Use the v2 steps for EUR until the shared Sell flow is migrated.
                            if (context.read<SellBloc>().state.fiatCurrency ==
                                FiatCurrency.eur) {
                              context.pushNamed(
                                SellRoute.sellPayoutV2.name,
                                extra: SellPayinSourceV2.wallet(wallet),
                              );
                            } else {
                              context.read<SellBloc>().add(
                                SellEvent.walletSelected(wallet: wallet),
                              );
                            }
                          },
                    localSignersOnly: true,
                  ),
                  const Gap(24.0),
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.sellExternalWallet),
                    subtitle: Text(context.loc.sellFromAnotherWallet),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isCreatingSellOrder
                        ? null
                        : () => context.pushNamed(
                            SellRoute.sellExternalWalletNetworkSelection.name,
                          ),
                  ),
                  const Gap(24.0),
                  const _SellError(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellError extends StatelessWidget {
  const _SellError();

  @override
  Widget build(BuildContext context) {
    final SellFailure? sellError = context.select(
      (SellBloc bloc) => bloc.state is SellWalletSelectionState
          ? (bloc.state as SellWalletSelectionState).error
          : null,
    );

    if (sellError == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        sellError.toTranslated(context),
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
