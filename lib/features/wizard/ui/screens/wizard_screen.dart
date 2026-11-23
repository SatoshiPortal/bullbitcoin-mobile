import 'dart:math';

import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
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
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullShapesX, BullSnackBar;

/// 4-page wizard body rendered inside [WizardApp] pre-init. Pure UI —
/// reads choices from the surrounding [WizardBloc] and dispatches
/// events on every user pick; dispatches `WizardEvent.completed()`
/// from the last page's "Get started" button. `initState` runs a
/// brightness probe and dispatches `WizardEvent.themeDetected` — it
/// reduces via `WizardChoices.copyWithSilent`, updating the displayed
/// theme without marking it as touched, so the user's existing setting
/// isn't clobbered when they tap Skip.
class WizardScreen extends StatefulWidget {
  const WizardScreen({
    required this.exchangeAllowed,
    required this.backgroundTasksAvailable,
    super.key,
  });
  final bool exchangeAllowed;
  final bool backgroundTasksAvailable;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  static const Duration _pageDuration = Duration(milliseconds: 300);
  static const Curve _pageCurve = Curves.easeInOut;

  final PageController _controller = PageController();
  WizardPage _page = WizardPage.welcome;

  /// Side of the mission Yes button, drawn at random so neither hand is
  /// favoured, and once so it stays put while the user swipes back and forth.
  final bool _yesFirst = Random().nextBool();

  static const List<WizardPage> _pages = WizardPage.values;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The user may have allowed notifications in the system settings.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!widget.backgroundTasksAvailable) return;
        context.read<WizardBloc>().add(
          const WizardEvent.notificationsRefreshed(),
        );
      },
    );
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
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _advance(WizardChoices choices) {
    if (_page.isLast) {
      _tryFinish(choices);
    } else {
      if (_page == WizardPage.customize) _confirmExchange();
      _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
    }
  }

  /// Mission step Yes/No tap → record consent + advance to journey
  /// step. Replaces the dots + Next button on the mission page.
  void _pickConsent(bool consent) {
    context.read<WizardBloc>().add(WizardEvent.consentPicked(consent));
    _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
  }

  /// The exchange switch shares the customize page, which every path to Next
  /// or Skip goes through: leaving that page confirms what it shows.
  void _confirmExchange() {
    if (!widget.exchangeAllowed) return;
    context.read<WizardBloc>().add(const WizardEvent.exchangeConfirmed());
  }

  void _tryFinish(WizardChoices choices) {
    _confirmExchange();
    if (choices.reportingConsent == null) {
      _controller.animateToPage(
        _pages.indexOf(WizardPage.mission),
        duration: _pageDuration,
        curve: _pageCurve,
      );
      BullSnackBar.show(context, message: context.loc.wizardMissionRequired);
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
                buildWhen: (a, b) =>
                    a.choices != b.choices ||
                    a.notificationsAllowed != b.notificationsAllowed ||
                    a.notificationsRefused != b.notificationsRefused,
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
                                  setState(() => _page = _pages[i]),
                              children: [
                                const WelcomeStep(),
                                CustomizeStep(
                                  exchangeAccess: widget.exchangeAllowed
                                      ? c.exchangeAccess
                                      : null,
                                  language: c.language,
                                  defaultCurrency: c.defaultCurrency,
                                  onThemePicked: (m) =>
                                      bloc.add(WizardEvent.themePicked(m)),
                                  onExchangePicked: (value) => bloc.add(
                                    WizardEvent.exchangePicked(value),
                                  ),
                                  onLanguagePicked: (l) =>
                                      bloc.add(WizardEvent.languagePicked(l)),
                                  onCurrencyPicked: (code) => bloc.add(
                                    WizardEvent.currencyPicked(code),
                                  ),
                                  backgroundTasks:
                                      widget.backgroundTasksAvailable
                                      ? c.backgroundTasks
                                      : null,
                                  onBackgroundTasksPicked: (value) => bloc.add(
                                    WizardEvent.backgroundTasksPicked(value),
                                  ),
                                  notificationsAllowed:
                                      state.notificationsAllowed,
                                  notificationsRefused:
                                      state.notificationsRefused,
                                  onNotificationsPicked: (value) => bloc.add(
                                    WizardEvent.notificationsPicked(value),
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
                                    borderRadius: BorderRadius.circular(
                                      context.bullShapes.dot,
                                    ),
                                  ),
                                  child: WizardDots(
                                    count: _pages.length,
                                    index: _pages.indexOf(_page),
                                  ),
                                ),
                                SizedBox(height: vGap),
                              ],
                              if (isMission)
                                MissionConsentRow(
                                  consent: c.reportingConsent,
                                  onYes: () => _pickConsent(true),
                                  onNo: () => _pickConsent(false),
                                  yesFirst: _yesFirst,
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: isWelcome
                                      ? BullButton.secondary(
                                          label: context.loc.wizardNextButton,
                                          onPressed: () => _advance(c),
                                        )
                                      : BullButton.primary(
                                          label: isLast
                                              ? context.loc.getStartedButton
                                              : context.loc.wizardNextButton,
                                          onPressed: () => _advance(c),
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
