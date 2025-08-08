import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/sats_bitcoin_unit_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.select(
      (SettingsCubit cubit) => cubit.state.currencyCode,
    );
    final availableCurrencies = context.select(
      (BitcoinPriceBloc bloc) => bloc.state.availableCurrencies,
    );

    Future<String?> openCurrencyBottomSheet({
      required BuildContext context,
      required List<String> availableCurrencies,
      required String selected,
    }) async {
      final c = await showModalBottomSheet<String?>(
        useRootNavigator: true,
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colour.secondaryFixedDim,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        builder: (context) {
          return CurrencyBottomSheet(
            availableCurrencies: availableCurrencies,
            selectedValue: selected,
          );
        },
      );

      return c;
    }

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Currency',
          color: context.colour.secondaryFixed,
          onBack: context.pop,
        ),
      ),
      backgroundColor: theme.colorScheme.secondaryFixed,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: BBText(
                    context.loc.satsBitcoinUnitSettingsLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  trailing: const SatsBitcoinUnitSwitch(),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: BBText(
                    'Default fiat currency',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  onTap:
                      currency == null ||
                              availableCurrencies == null ||
                              availableCurrencies.isEmpty
                          ? null
                          : () async {
                            final selectedCurrency =
                                await openCurrencyBottomSheet(
                                  context: context,
                                  availableCurrencies: availableCurrencies,
                                  selected: currency,
                                );
                            // If the user selected a different currency, update it
                            // in the settings.
                            if (selectedCurrency != null &&
                                selectedCurrency != currency) {
                              if (context.mounted) {
                                await context
                                    .read<SettingsCubit>()
                                    .changeCurrency(selectedCurrency);
                              }
                            }
                          },
                  trailing: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
