import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart'
    show TranslationWarningBottomSheet;
import 'package:network/network.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullLanguagePicker,
        BullPickerItem,
        BullSettingsEntryItem,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLanguage = context.select(
      (SettingsCubit cubit) =>
          cubit.state.language ?? Language.unitedStatesEnglish,
    );

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
                            context.read<SettingsCubit>().changeLanguage(lang);
                            if (lang.isMachineTranslated) {
                              TranslationWarningBottomSheet.show(context);
                            }
                          },
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.vpn_lock,
                        title: context.loc.torSettingsTitle,
                        onTap: () => context.pushNamed(
                          TorSettingsRoute.torSettings.name,
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.hub,
                        title:
                            context.loc.onboardingAdvancedOptionsCustomElectrum,
                        onTap: () {
                          context.pushNamed(
                            ElectrumSettingsRoute.electrumSettings.name,
                          );
                        },
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.memory,
                        title:
                            context.loc.onboardingAdvancedOptionsCustomMempool,
                        onTap: () {
                          context.pushNamed(MempoolSettingsRoute.name);
                        },
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
