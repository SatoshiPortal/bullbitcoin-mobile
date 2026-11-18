import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/advanced_options.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/create_wallet_button.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/recover_backup_button.dart';
import 'package:bb_mobile/features/settings/ui/widgets/superuser_tap_unlocker.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullText, BullTypography, Gap, BullTypographyX;

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
                  BullText(
                    context.loc.onboardingBullBitcoin,
                    style: TextStyle(
                      fontFamily: BullTypography.brandFamily,
                      fontSize: 54, // Brand wordmark: a layout size, not a role (bull-ui-check allowlist).
                      fontWeight: .w500,
                      color: context.appColors.onPrimaryFixed,
                      height: 1,
                    ),
                  ),
                  BullText(
                    context.loc.onboardingOwnYourMoney,
                    style: TextStyle(
                      fontFamily: BullTypography.brandFamily,
                      fontSize: 40, // Brand wordmark: a layout size, not a role (bull-ui-check allowlist).
                      fontWeight: .w500,
                      color: context.appColors.secondaryFixed,
                      height: 1,
                    ),
                  ),
                  const Gap(10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: BullText(
                      context.loc.onboardingSplashDescription,
                      style: context.bullType.caption,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceFixed,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (creating || loading) ...[
            Center(
              child: CircularProgressIndicator(
                color: context.appColors.primaryFixed,
              ),
            ),
          ] else ...[
            const CreateWalletButton(),
            const Gap(10),
            const RecoverWalletButton(),
            const Gap(8),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MultiBlocProvider(
                        providers: [
                          BlocProvider(
                            create: (_) => locator<ElectrumSettingsBloc>()
                              ..add(
                                const ElectrumSettingsLoaded(isLiquid: false),
                              ),
                          ),
                        ],
                        child: const AdvancedOptions(),
                      ),
                    ),
                  );
                },
                child: Text(
                  context.loc.onboardingAdvancedOptionsTitle,
                  style: context.bullType.body.copyWith(
                    color: context.appColors.primaryFixed,
                    decoration: TextDecoration.underline,
                    decorationColor: context.appColors.primaryFixed,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
