import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/advanced_options.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/create_wallet_button.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/recover_backup_button.dart';
import 'package:bb_mobile/features/settings/ui/widgets/superuser_tap_unlocker.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class OnboardingSplash extends StatelessWidget {
  const OnboardingSplash({super.key, this.loading = false});

  final bool loading;
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            const _BG(),
            Center(
              child: Column(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  const Spacer(flex: 2),
                  SuperuserTapUnlocker(
                    child: Image.asset(
                      Assets.logos.bbLogoWhite.path,
                      height: 127,
                    ),
                  ),
                  const Gap(36),
                  BBText(
                    context.loc.onboardingBullBitcoin,
                    style: AppFonts.textTitleTheme.textStyle.copyWith(
                      fontSize: 54,
                      fontWeight: .w500,
                      color: context.appColors.onPrimaryFixed,
                      height: 1,
                    ),
                  ),
                  BBText(
                    context.loc.onboardingOwnYourMoney,
                    style: AppFonts.textTitleTheme.textStyle.copyWith(
                      fontSize: 40,
                      fontWeight: .w500,
                      color: context.appColors.secondaryFixed,
                      height: 1,
                    ),
                  ),
                  const Gap(10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: BBText(
                      context.loc.onboardingSplashDescription,
                      style: context.font.labelSmall,
                      color: context.appColors.onPrimaryFixed,
                      textAlign: .center,
                      maxLines: 2,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 40,
                    ),
                    child: _Actions(loading: loading),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.loading});

  final bool loading;
  @override
  Widget build(BuildContext context) {
    bool creating = false;
    if (!loading) {
      creating = context.select(
        (OnboardingBloc bloc) => bloc.state.loadingCreate,
      );
    }

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (creating || loading) ...[
          Center(
            child: CircularProgressIndicator(
              color: context.appColors.onPrimaryFixed,
            ),
          ),
        ] else ...[
          const CreateWalletButton(),
          const Gap(10),
          const RecoverWalletButton(),
          const Gap(16),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => MultiBlocProvider(
                          providers: [
                            BlocProvider(
                              create:
                                  (_) =>
                                      locator<ElectrumSettingsBloc>()..add(
                                        const ElectrumSettingsLoaded(
                                          isLiquid: false,
                                        ),
                                      ),
                            ),
                            BlocProvider(
                              create: (_) => locator<TorSettingsCubit>(),
                            ),
                          ],
                          child: const AdvancedOptions(),
                        ),
                  ),
                );
              },
              child: Text(
                'Advanced Options',
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onPrimaryFixed.withValues(
                    alpha: 0.9,
                  ),
                  decoration: TextDecoration.underline,
                  decorationColor: context.appColors.onPrimaryFixed
                      .withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BG extends StatelessWidget {
  const _BG();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: context.appColors.primaryFixed,
          height: double.infinity,
          width: double.infinity,
        ),
        Opacity(
          opacity: 0.2,
          child: Transform.rotate(
            angle: 3.141,
            child: Image.asset(
              Assets.backgrounds.bgLong.path,
              fit: .cover,
              height: double.infinity,
              width: double.infinity,
            ),
          ),
        ),
      ],
    );
  }
}
