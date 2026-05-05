import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/presentation/bloc/wizard_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/customize_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/journey_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/mission_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/welcome_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_dots.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_header.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 4-page wizard body rendered inside [WizardApp] pre-init. Pure UI —
/// reads choices from the surrounding [WizardBloc] and dispatches
/// events on every user pick; dispatches `WizardEvent.completed()`
/// from the last page's "Get started" button. `initState` performs
/// system probes (keyboard locale + brightness) and dispatches
/// `WizardEvent.themeDetected` / `languageDetected` — both reduce via
/// `WizardChoices.copyWithSilent`, updating the displayed value
/// without marking the field as touched, so the user's existing
/// settings aren't clobbered when they tap Skip.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  static const int _totalSteps = 4;
  // Mission step index — `Skip`/`Next` jump here when consent is unset.
  static const int _missionPage = 2;

  static const Duration _pageDuration = Duration(milliseconds: 300);
  static const Curve _pageCurve = Curves.easeInOut;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final detectedLang = Language.fromKeyboard();
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final detectedTheme = brightness == Brightness.dark
        ? AppThemeMode.dark
        : AppThemeMode.light;

    final c = context.read<WizardBloc>().state.choices;
    final needsLangUpdate =
        detectedLang != Language.unitedStatesEnglish &&
        c.language == Language.unitedStatesEnglish;
    final needsThemeUpdate = c.themeMode == AppThemeMode.system;
    if (!needsLangUpdate && !needsThemeUpdate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<WizardBloc>();
      // `themeDetected` / `languageDetected` reduce via `copyWithSilent`
      // — they update the displayed value WITHOUT marking the field as
      // touched, so auto-detected values (brightness + keyboard) don't
      // get committed to user settings unless the user later confirms
      // via the picker. Critical because the wizard re-shows on every
      // `kCurrentWizardVersion` bump for existing users — their stored
      // language/theme would otherwise be clobbered when they tap Skip.
      if (needsThemeUpdate) {
        bloc.add(WizardEvent.themeDetected(detectedTheme));
      }
      if (needsLangUpdate) {
        bloc.add(WizardEvent.languageDetected(detectedLang));
        TranslationWarningBottomSheet.show(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance(WizardChoices choices) {
    // Block leaving the mission step until the user explicitly picks Yes/No.
    if (_page == _missionPage && choices.reportingConsent == null) {
      SnackBarUtils.showSnackBar(context, context.loc.wizardMissionRequired);
      return;
    }
    if (_page < _totalSteps - 1) {
      _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
    } else {
      _tryFinish(choices);
    }
  }

  void _tryFinish(WizardChoices choices) {
    if (choices.reportingConsent == null) {
      _controller.animateToPage(
        _missionPage,
        duration: _pageDuration,
        curve: _pageCurve,
      );
      SnackBarUtils.showSnackBar(context, context.loc.wizardMissionRequired);
      return;
    }
    context.read<WizardBloc>().add(const WizardEvent.completed());
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _totalSteps - 1;
    final hPad = Device.screen.width * 0.06;
    final vGap = Device.screen.height * 0.02;

    final isWelcome = _page == 0;
    return PopScope(
      // Block the actual app pop. The handler below intercepts the
      // gesture and steps the PageView back one page instead — except
      // on page 1, where we silently swallow the pop so the consent
      // collection can't be skipped before `Bull.init` migrations run.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page > 0) {
          _controller.previousPage(duration: _pageDuration, curve: _pageCurve);
        }
      },
      child: Scaffold(
        // Page 1 reads as a splash — full-bleed red + bgLong pattern
        // painted behind the Scaffold body so it extends under the dots
        // and Next button strip too. Other pages use the normal bg.
        backgroundColor: isWelcome
            ? context.appColors.primaryFixed
            : context.appColors.background,
        body: Stack(
          children: [
            if (isWelcome) const _WelcomeBgPattern(),
            SafeArea(
              child: BlocBuilder<WizardBloc, WizardState>(
                buildWhen: (a, b) => a.choices != b.choices,
                builder: (context, state) {
                  final c = state.choices;
                  final bloc = context.read<WizardBloc>();
                  return Column(
                    children: [
                      // Header (small logo + Skip) is hidden on page 1 to
                      // keep the splash visual clean; reappears on page 2+.
                      if (!isWelcome) WizardHeader(onSkip: () => _tryFinish(c)),
                      Expanded(
                        child: PageView(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _page = i),
                          children: [
                            const WelcomeStep(),
                            CustomizeStep(
                              stepIndex: 1,
                              totalSteps: _totalSteps,
                              themeMode: c.themeMode,
                              language: c.language,
                              defaultCurrency: c.defaultCurrency,
                              onThemePicked: (m) =>
                                  bloc.add(WizardEvent.themePicked(m)),
                              onLanguagePicked: (l) =>
                                  bloc.add(WizardEvent.languagePicked(l)),
                              onCurrencyPicked: (code) =>
                                  bloc.add(WizardEvent.currencyPicked(code)),
                            ),
                            MissionStep(
                              stepIndex: _missionPage,
                              totalSteps: _totalSteps,
                              consent: c.reportingConsent,
                              onChanged: (v) =>
                                  bloc.add(WizardEvent.consentPicked(v)),
                            ),
                            JourneyStep(stepIndex: 3, totalSteps: _totalSteps),
                          ],
                        ),
                      ),
                      SizedBox(height: vGap),
                      WizardDots(
                        count: _totalSteps,
                        index: _page,
                        // On the red splash bg the default red active dot
                        // is invisible. Switch to white-on-red.
                        activeColor: isWelcome
                            ? context.appColors.onPrimaryFixed
                            : null,
                        inactiveColor: isWelcome
                            ? context.appColors.onPrimaryFixed.withValues(
                                alpha: 0.4,
                              )
                            : null,
                      ),
                      SizedBox(height: vGap),
                      Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
                        child: SizedBox(
                          width: double.infinity,
                          child: BBButton.big(
                            label: isLast
                                ? context.loc.getStartedButton
                                : context.loc.wizardNextButton,
                            onPressed: () => _advance(c),
                            // Same scheme as `CreateWalletButton` on the
                            // splash: high-contrast against the red bg on
                            // page 1; brand red elsewhere.
                            bgColor: isWelcome
                                ? context.appColors.secondaryFixed
                                : context.appColors.primary,
                            textColor: isWelcome
                                ? context.appColors.onSecondaryFixed
                                : context.appColors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red + `bgLong` pattern painted behind the whole `Scaffold` body on
/// page 1 so the splash visual extends under the dots and Next button.
/// Mirrors `OnboardingSplash._BG`.
class _WelcomeBgPattern extends StatelessWidget {
  const _WelcomeBgPattern();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: context.appColors.primaryFixed),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.2,
            child: Transform.rotate(
              angle: 3.141,
              child: Image.asset(
                Assets.backgrounds.bgLong.path,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
