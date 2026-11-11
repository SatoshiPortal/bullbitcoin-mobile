import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/presentation/pay_failure_l10n.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullScrollableColumn, Gap;
import 'package:go_router/go_router.dart';

class PayWalletSelectionScreen extends StatefulWidget {
  const PayWalletSelectionScreen({super.key});

  @override
  State<PayWalletSelectionScreen> createState() =>
      _PayWalletSelectionScreenState();
}

class _PayWalletSelectionScreenState extends State<PayWalletSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Show wallet values in the pay flow's currency. Once, on open: sent
    // from build, it went out again on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currency = context.read<PayBloc>().state.currency;
      context.read<BitcoinPriceBloc>().add(
        BitcoinPriceCurrencyChanged(currencyCode: currency.code),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingPayOrder = context.select(
      (PayBloc bloc) => bloc.state is PayPreparingPaymentState,
    );

    final currency = context.select((PayBloc bloc) => bloc.state.currency);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.paySelectWallet)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BullScrollableColumn(
                children: [
                  const Gap(24.0),
                  Text(
                    context.loc.payWhichWallet,
                    style: context.font.labelMedium?.copyWith(
                      color: context.appColors.text,
                    ),
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
                  ListTile(
                    tileColor: context.appColors.onSecondary,
                    shape: const Border(),
                    title: Text(context.loc.payExternalWallet),
                    subtitle: Text(context.loc.payExternalWalletDescription),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isCreatingPayOrder
                        ? null
                        : () => context.pushNamed(
                            PayRoute.payExternalWalletNetworkSelection.name,
                            extra: context.read<PayBloc>(),
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
