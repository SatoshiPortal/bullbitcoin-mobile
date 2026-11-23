import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:network/network.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:settings/settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullLanguagePicker,
        BullPickerItem,
        BullSettingsEntryItem,
        Gap,
        BullTypographyX;

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLanguage =
        Settings.languageOf(context) ?? Language.unitedStatesEnglish;

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.onboardingAdvancedOptionsTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          context.loc.onboardingAdvancedOptionsDescription,
                          style: context.bullType.body.copyWith(
                            color: context.appColors.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      BullSettingsEntryItem(
                        icon: Icons.language,
                        title: context.loc.settingsLanguageTitle,
                        trailing: BullLanguagePicker<Language>(
                          value: currentLanguage,
                          languages: [
                            for (final language in Language.values)
                              BullPickerItem(
                                value: language,
                                label: language.label,
                              ),
                          ],
                          onChanged: (lang) {
                            Settings.changeLanguage(context, lang);
                            if (lang.isMachineTranslated) {
                              TranslationWarningBottomSheet.show(context);
                            }
                          },
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.vpn_lock,
                        title: context.loc.torSettingsTitle,
                        onTap: () => NetworkNavigation.open(
                          context,
                          section: NetworkSection.tor,
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.hub,
                        title:
                            context.loc.onboardingAdvancedOptionsCustomElectrum,
                        onTap: () => NetworkNavigation.open(
                          context,
                          section: NetworkSection.electrum,
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.memory,
                        title:
                            context.loc.onboardingAdvancedOptionsCustomMempool,
                        onTap: () => NetworkNavigation.open(
                          context,
                          section: NetworkSection.mempool,
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.cloud_circle,
                        title: context
                            .loc
                            .onboardingAdvancedOptionsCustomRecoverbull,
                        onTap: () {
                          RecoverBullFeature.open(
                            context,
                            RecoverBullFlow.settings,
                          );
                        },
                      ),
                      const Gap(24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          context.loc.onboardingAdvancedOptionsFooter,
                          style: context.bullType.label
                              .copyWith(fontWeight: FontWeight.w400)
                              .copyWith(
                                color: context.appColors.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
