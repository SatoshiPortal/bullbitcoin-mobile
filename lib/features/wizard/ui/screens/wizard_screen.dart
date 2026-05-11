import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/presentation/bloc/wizard_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/customize_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/journey_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/mission_consent_row.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/mission_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/welcome_bg_pattern.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/welcome_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_dots.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 4-page wizard body rendered inside [WizardApp] pre-init. Pure UI —
/// reads choices from the surrounding [WizardBloc] and dispatches
/// events on every user pick; dispatches `WizardEvent.completed()`
/// from the last page's "Get started" button. `initState` runs a
/// brightness probe and dispatches `WizardEvent.themeDetected` — it
/// reduces via `WizardChoices.copyWithSilent`, updating the displayed
/// theme without marking it as touched, so the user's existing setting
/// isn't clobbered when they tap Skip.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  static const Duration _pageDuration = Duration(milliseconds: 300);
  static const Curve _pageCurve = Curves.easeInOut;

  final PageController _controller = PageController();
  WizardPage _page = WizardPage.welcome;

  @override
  void initState() {
    super.initState();
    final c = context.read<WizardBloc>().state.choices;
    if (c.themeMode != AppThemeMode.system) return;
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final detectedTheme = brightness == Brightness.dark
        ? AppThemeMode.dark
        : AppThemeMode.light;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // `themeDetected` reduces via `copyWithSilent` — updates the
      // displayed value WITHOUT marking the field as touched, so the
      // brightness-detected value doesn't get committed to user
      // settings unless the user later confirms via the picker.
      // Critical because the wizard re-shows on every
      // `kCurrentWizardVersion` bump for existing users — their stored
      // theme would otherwise be clobbered when they tap Skip.
      context.read<WizardBloc>().add(WizardEvent.themeDetected(detectedTheme));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance(WizardChoices choices) {
    if (_page.isLast) {
      _tryFinish(choices);
    } else {
      _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
    }
  }

  /// Mission step Yes/No tap → record consent + advance to journey
  /// step. Replaces the dots + Next button on the mission page.
  void _pickConsent(bool consent) {
    context.read<WizardBloc>().add(WizardEvent.consentPicked(consent));
    _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
  }

  void _tryFinish(WizardChoices choices) {
    if (choices.reportingConsent == null) {
      _controller.animateToPage(
        WizardPage.mission.index,
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
    final hPad = Device.screen.width * 0.06;
    final vGap = Device.screen.height * 0.02;

    final isWelcome = _page == WizardPage.welcome;
    final isMission = _page == WizardPage.mission;
    final isLast = _page.isLast;
    return PopScope(
      // Block the actual app pop. The handler below intercepts the
      // gesture and steps the PageView back one page instead — except
      // on page 1, where we silently swallow the pop so the consent
      // collection can't be skipped before `Bull.init` migrations run.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_page.isFirst) {
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
            if (isWelcome) const WelcomeBgPattern(),
            SafeArea(
              child: BlocBuilder<WizardBloc, WizardState>(
                buildWhen: (a, b) => a.choices != b.choices,
                builder: (context, state) {
                  final c = state.choices;
                  final bloc = context.read<WizardBloc>();
                  return Stack(
                    children: [
                      // Page content fills the whole SafeArea. The
                      // bottom chrome (dots + button or Yes/No) floats
                      // on top via a Positioned overlay so steps can
                      // scroll their content past it without a hard
                      // visual cut. Each step's `WizardStepLayout`
                      // adds bottom padding equal to `kWizardChromeHeight`
                      // so the last item can settle right above the
                      // chrome at max-scroll.
                      Column(
                        children: [
                          if (!isWelcome)
                            WizardHeader(onSkip: () => _tryFinish(c)),
                          Expanded(
                            child: PageView(
                              controller: _controller,
                              onPageChanged: (i) =>
                                  setState(() => _page = WizardPage.values[i]),
                              children: [
                                const WelcomeStep(),
                                CustomizeStep(
                                  themeMode: c.themeMode,
                                  language: c.language,
                                  defaultCurrency: c.defaultCurrency,
                                  onThemePicked: (m) =>
                                      bloc.add(WizardEvent.themePicked(m)),
                                  onLanguagePicked: (l) =>
                                      bloc.add(WizardEvent.languagePicked(l)),
                                  onCurrencyPicked: (code) => bloc.add(
                                    WizardEvent.currencyPicked(code),
                                  ),
                                ),
                                const MissionStep(),
                                const JourneyStep(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, vGap, hPad, hPad),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Dots hidden on the welcome splash — the
                              // page reads as a self-contained intro
                              // without progress chrome competing with
                              // the centered logo + tagline.
                              if (!isWelcome) ...[
                                // Small pill behind the dots so they
                                // stay legible on top of the page
                                // content scrolling underneath.
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.appColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: WizardDots(
                                    count: WizardPage.total,
                                    index: _page.index,
                                  ),
                                ),
                                SizedBox(height: vGap),
                              ],
                              if (isMission)
                                MissionConsentRow(
                                  consent: c.reportingConsent,
                                  onYes: () => _pickConsent(true),
                                  onNo: () => _pickConsent(false),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: BBButton.big(
                                    label: isLast
                                        ? context.loc.getStartedButton
                                        : context.loc.wizardNextButton,
                                    onPressed: () => _advance(c),
                                    // Same scheme as `CreateWalletButton`
                                    // on the splash: high-contrast
                                    // against the red bg on page 1;
                                    // brand red elsewhere.
                                    bgColor: isWelcome
                                        ? context.appColors.secondaryFixed
                                        : context.appColors.primary,
                                    textColor: isWelcome
                                        ? context.appColors.onSecondaryFixed
                                        : context.appColors.onPrimary,
                                  ),
                                ),
                            ],
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
