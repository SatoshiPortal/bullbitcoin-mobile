import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dark_mode_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/dev_mode_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/screen_capture_protection_switch.dart';
import 'package:bb_mobile/features/settings/ui/widgets/testnet_mode_switch.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bull_pricer/bull_pricer.dart' show SupportedCurrency;
import 'package:bull_ui/bull_ui.dart'
    show BullLanguagePicker, BullPickerChip, BullPickerItem, BullSnackBar;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLanguage = context.select(
      (SettingsCubit cubit) =>
          cubit.state.language ?? Language.unitedStatesEnglish,
    );
    final currency = context.select(
      (SettingsCubit cubit) => cubit.state.currencyCode,
    );
    final availableCurrencies = context.select(
      (BitcoinPriceBloc bloc) => bloc.state.availableCurrencies,
    );
    final items = settingsItemsOf(context);

    Widget? trailingFor(SettingsItemId id) => switch (id) {
      SettingsItemId.language => BullLanguagePicker<Language>(
        value: currentLanguage,
        languages: [
          for (final language in Language.values)
            BullPickerItem(value: language, label: language.label),
        ],
        onChanged: (lang) {
          context.read<SettingsCubit>().changeLanguage(lang);
          if (lang.isMachineTranslated) {
            TranslationWarningBottomSheet.show(context);
          }
        },
      ),
      SettingsItemId.currency =>
        currency == null ||
                availableCurrencies == null ||
                availableCurrencies.isEmpty
            ? null
            : BullPickerChip<String>(
                tooltip: context.loc.currencySettingsDefaultFiatCurrencyLabel,
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
                  context.read<SettingsCubit>().changeCurrency(picked);
                },
              ),
      SettingsItemId.theme => const DarkModeSwitch(),
      SettingsItemId.screenPrivacy => const ScreenCaptureProtectionSwitch(),
      SettingsItemId.devMode => const DevModeSwitch(),
      SettingsItemId.testnetMode => const TestnetModeSwitch(),
      SettingsItemId.errorReporting => const ErrorReportingSwitch(),
      _ => null,
    };

    return BlocListener<SettingsCubit, SettingsState>(
      // Turning dev mode off revokes the SP wallet. The revoke leaves a
      // `.revoked` sentinel even when the on-disk delete fails, so the wallet
      // is unloadable but still there; the user is the only one who can retry.
      listenWhen: (previous, current) =>
          !previous.revokeSpFailed && current.revokeSpFailed,
      listener: (context, state) => BullSnackBar.show(
        context,
        message: context.loc.settingsDevModeSpRevokeFailed,
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.settingsAppSettingsTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final item in items.inSection(SettingsItemSection.app))
                    item.buildTile(context, trailing: trailingFor(item.id)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
