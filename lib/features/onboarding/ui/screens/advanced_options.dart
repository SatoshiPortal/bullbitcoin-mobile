import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/app_language_picker.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/mempool_settings/router.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_proxy_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class AdvancedOptions extends StatefulWidget {
  const AdvancedOptions({super.key});

  @override
  State<AdvancedOptions> createState() => _AdvancedOptionsState();
}

class _AdvancedOptionsState extends State<AdvancedOptions> {
  @override
  void initState() {
    super.initState();
    context.read<TorSettingsCubit>().init();
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = context.select(
      (SettingsCubit cubit) =>
          cubit.state.language ?? Language.unitedStatesEnglish,
    );

    return BullPage(
      topBar: BullTopBar(
        title: context.loc.onboardingAdvancedOptionsTitle,
        onBack: context.pop,
      ),
      padding: EdgeInsets.zero,
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
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                    const Gap(8),
                    const TorProxyWidget(),
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
                      title: context.loc.onboardingAdvancedOptionsCustomMempool,
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
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                    BullSettingsEntryItem(
                      icon: Icons.language,
                      title: context.loc.settingsLanguageTitle,
                      trailing: AppLanguagePicker(
                        value: currentLanguage,
                        onChanged: (lang) =>
                            context.read<SettingsCubit>().changeLanguage(lang),
                      ),
                    ),
                    const Gap(24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        context.loc.onboardingAdvancedOptionsFooter,
                        style: context.font.bodySmall?.copyWith(
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
            Padding(
              padding: EdgeInsets.only(bottom: Device.screen.height * 0.05),
              child: BullButton.primary(
                label: context.loc.onboardingAdvancedOptionsDone,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
