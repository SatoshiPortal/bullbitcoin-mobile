import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_settings_dropdown.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dev_mode_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    final currentLanguage = context.select(
      (SettingsCubit cubit) =>
          cubit.state.language ?? Language.unitedStatesEnglish,
    );
    final currentTheme = context.select(
      (SettingsCubit cubit) =>
          cubit.state.storedSettings?.themeMode ?? AppThemeMode.system,
    );
    final bitcoinUnit = context.select(
      (SettingsCubit cubit) => cubit.state.bitcoinUnit ?? BitcoinUnit.sats,
    );
    final currencyCode = context.select(
      (SettingsCubit cubit) => cubit.state.currencyCode ?? 'USD',
    );
    final availableCurrencies = context.select(
      (BitcoinPriceBloc bloc) => bloc.state.availableCurrencies,
    );
    final useTorProxy = context.select(
      (SettingsCubit cubit) => cubit.state.storedSettings?.useTorProxy ?? false,
    );
    final isPinCodeSet = context.select(
      (SettingsCubit cubit) => cubit.state.isPinCodeSet,
    );

    return Scaffold(
      appBar: AppBar(
        title: BBText(
          context.loc.settingsAppSettingsTitle,
          style: context.font.headlineMedium,
          color: context.appColors.text,
        ),
        backgroundColor: context.appColors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appColors.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.language,
                  title: context.loc.settingsLanguageTitle,
                  trailing: BBSettingsDropdown<Language>(
                    value: currentLanguage,
                    items: Language.values,
                    labelBuilder: (language) => language.label,
                    onChanged: (Language? newLanguage) {
                      if (newLanguage != null) {
                        context.read<SettingsCubit>().changeLanguage(
                          newLanguage,
                        );
                        if (newLanguage != Language.unitedStatesEnglish) {
                          TranslationWarningBottomSheet.show(context);
                        }
                      }
                    },
                  ),
                ),
                SettingsEntryItem(
                  icon: Icons.palette_outlined,
                  title: context.loc.settingsThemeTitle,
                  trailing: BBSettingsDropdown<AppThemeMode>(
                    value: currentTheme,
                    items: AppThemeMode.values,
                    labelBuilder: _getThemeLabel,
                    onChanged: (AppThemeMode? newTheme) {
                      if (newTheme != null) {
                        context.read<SettingsCubit>().changeThemeMode(newTheme);
                      }
                    },
                  ),
                ),
                SettingsEntryItem(
                  icon: Icons.attach_money,
                  title: context.loc.currencySettingsDefaultFiatCurrencyLabel,
                  trailing:
                      availableCurrencies != null &&
                          availableCurrencies.isNotEmpty
                      ? BBSettingsDropdown<String>(
                          value: currencyCode,
                          items: availableCurrencies,
                          labelBuilder: (currency) => currency,
                          onChanged: (String? newCurrency) {
                            if (newCurrency != null) {
                              context.read<SettingsCubit>().changeCurrency(
                                newCurrency,
                              );
                            }
                          },
                        )
                      : Text(
                          currencyCode,
                          style: context.font.bodyMedium?.copyWith(
                            color: context.appColors.primary,
                          ),
                        ),
                ),
                SettingsEntryItem(
                  icon: Icons.currency_bitcoin,
                  title: context.loc.satsBitcoinUnitSettingsLabel,
                  trailing: BBSettingsDropdown<BitcoinUnit>(
                    value: bitcoinUnit,
                    items: BitcoinUnit.values,
                    labelBuilder: (unit) => unit.code,
                    onChanged: (BitcoinUnit? newUnit) {
                      if (newUnit != null) {
                        context.read<SettingsCubit>().toggleSatsUnit(
                          newUnit == BitcoinUnit.sats,
                        );
                      }
                    },
                  ),
                ),
                SettingsEntryItem(
                  icon: Icons.fiber_pin,
                  title: context.loc.settingsSecurityPinTitle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPinCodeSet ? 'Enabled' : 'Disabled',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: context.appColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () async {
                    await context.pushNamed(SettingsRoute.pinCode.name);
                    if (context.mounted) {
                      context.read<SettingsCubit>().refreshPinCodeStatus();
                    }
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.vpn_lock,
                  title: context.loc.settingsTorSettingsTitle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        useTorProxy ? 'On' : 'Off',
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: context.appColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                  onTap: () {
                    context.pushNamed(TorSettingsRoute.torSettings.name);
                  },
                ),
                SettingsEntryItem(
                  icon: Icons.article_outlined,
                  title: context.loc.logSettingsLogsTitle,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.appColors.primary,
                    size: 20,
                  ),
                  onTap: () {
                    context.pushNamed(SettingsRoute.logs.name);
                  },
                ),
                if (isSuperuser)
                  SettingsEntryItem(
                    icon: Icons.logo_dev,
                    title: context.loc.appSettingsDevModeTitle,
                    trailing: const DevModeSwitch(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
