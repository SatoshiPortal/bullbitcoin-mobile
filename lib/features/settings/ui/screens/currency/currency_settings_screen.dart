import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/sats_bitcoin_unit_switch.dart';
import 'package:material_ui/material_ui.dart';
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

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.settingsCurrencyTitle,
          color: context.appColors.background,
          onBack: context.pop,
        ),
      ),
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                  ),
                  tileColor: context.appColors.transparent,
                  title: BBText(
                    context.loc.satsBitcoinUnitSettingsLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                  ),
                  trailing: const SatsBitcoinUnitSwitch(),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                  ),
                  tileColor: context.appColors.transparent,
                  title: BBText(
                    context.loc.currencySettingsDefaultFiatCurrencyLabel,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                  ),
                  trailing:
                      currency == null ||
                          availableCurrencies == null ||
                          availableCurrencies.isEmpty
                      ? null
                      : BullPickerChip<String>(
                          tooltip: context
                              .loc
                              .currencySettingsDefaultFiatCurrencyLabel,
                          value: currency,
                          items: [
                            for (final code in availableCurrencies)
                              BullPickerItem(
                                value: code,
                                label:
                                    '${SupportedCurrency.tryFromCode(code)?.flag ?? ''} $code',
                              ),
                          ],
                          onChanged: (picked) {
                            if (picked == currency) return;
                            context.read<SettingsCubit>().changeCurrency(
                              picked,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
