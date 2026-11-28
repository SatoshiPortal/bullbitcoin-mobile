import 'package:bull_logger/startup_bench.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:onboarding/src/onboarding_l10n.dart';
import 'package:onboarding/src/presentation/bloc/onboarding_bloc.dart';
import 'package:onboarding/src/ui/widgets/create_wallet_button.dart';
import 'package:onboarding/src/ui/widgets/recover_backup_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAdvancedOptionsLink,
        BullText,
        BullTypography,
        Gap,
        BullTypographyX;

class OnboardingSplash extends StatelessWidget {
  const OnboardingSplash({
    super.key,
    required this.loading,
    required this.logo,
    required this.background,
    required this.advancedOptions,
  });

  final bool loading;
  final Widget logo;
  final ImageProvider background;
  final WidgetBuilder advancedOptions;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupBench.markOnce(
        loading ? 'onboarding_loading_frame' : 'onboarding_ready_frame',
      );
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // Only the backdrop differs between the two states: the loading
            // page carries the full-page black camo treatment, the
            // create/recover page keeps the injected branded background and
            // grid. The logo stays injected either way, so the host keeps its
            // tap-to-unlock wrapper on both screens.
            if (loading) const _CamoBackground() else _BG(background),
            Center(
              child: Column(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  const Spacer(flex: 2),
                  logo,
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
                      // The camo backdrop is brand graphite in both themes, so
                      // the tagline cannot use secondaryFixed here.
                      color: loading
                          ? context.appColors.onPrimaryFixed
                          : context.appColors.secondaryFixed,
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
                    child: Theme(
                      data: AppTheme.themeData(AppThemeType.light),
                      child: _Actions(
                        loading: loading,
                        advancedOptions: advancedOptions,
                      ),
                    ),
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
  const _Actions({required this.loading, required this.advancedOptions});

  final bool loading;
  final WidgetBuilder advancedOptions;
  @override
  Widget build(BuildContext context) {
    bool creating = false;
    if (!loading) {
      creating = context.select(
        (OnboardingBloc bloc) => bloc.state.loadingCreate,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
            const Gap(8),
            Center(
              child: BullAdvancedOptionsLink(
                label: context.loc.onboardingAdvancedOptionsTitle,
                color: context.appColors.onPrimaryFixed,
                bold: true,
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: advancedOptions));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-page black camo backdrop of the loading splash.
///
/// The texture is the app icon's graphite camo with its static red bull
/// removed; see `README.md` in this package for its provenance. It is 512 px
/// square and only has to cover, so it is not stretched.
class _CamoBackground extends StatelessWidget {
  const _CamoBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: context.appColors.graphiteFixed,
          height: double.infinity,
          width: double.infinity,
        ),
        Image.asset(
          'assets/splash/splash_camo.png',
          package: 'onboarding',
          fit: .cover,
          height: double.infinity,
          width: double.infinity,
          excludeFromSemantics: true,
        ),
      ],
    );
  }
}

class _BG extends StatelessWidget {
  const _BG(this.background);

  final ImageProvider background;

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
            child: Image(
              image: background,
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
