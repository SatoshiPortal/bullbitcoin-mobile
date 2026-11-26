import 'dart:math';

import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:wizard/src/wizard_localizations_context.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/presentation/bloc/wizard_bloc.dart';
import 'package:wizard/src/ui/wizard_page.dart';
import 'package:wizard/src/ui/wizard_branding.dart';
import 'package:wizard/src/ui/widgets/customize_step.dart';
import 'package:wizard/src/ui/widgets/journey_step.dart';
import 'package:wizard/src/ui/widgets/mission_consent_row.dart';
import 'package:wizard/src/ui/widgets/mission_step.dart';
import 'package:wizard/src/ui/widgets/welcome_bg_pattern.dart';
import 'package:wizard/src/ui/widgets/welcome_step.dart';
import 'package:wizard/src/ui/widgets/wizard_dots.dart';
import 'package:wizard/src/ui/widgets/wizard_header.dart';
import 'package:wizard/src/ui/widgets/wizard_network_control.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:settings/settings.dart' show SettingsLocalizations;
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullLoader, BullShapesX, BullSnackBar;

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
    required this.branding,
    this.allowDeveloperNetwork = false,
    super.key,
  });
  final bool exchangeAllowed;
  final bool backgroundTasksAvailable;
  final WizardBranding branding;
  final bool allowDeveloperNetwork;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  static const Duration _pageDuration = Duration(milliseconds: 300);
  static const Curve _pageCurve = Curves.easeInOut;

  final PageController _controller = PageController();
  WizardPage _page = WizardPage.welcome;

  /// Superuser mode, unlocked on the welcome page and read by the settings
  /// step. Kept here, not in the bloc, as it only gates what is shown; the
  /// choices it leads to are in the bloc.
  bool _superuser = false;
  bool _networkConsented = false;
  bool _busy = false;
  bool _retryRequired = false;
  bool _completionDispatched = false;
  bool _frameCallbackScheduled = false;

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
        if (_busy && !_completionDispatched) _scheduleCompletion();
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
      _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
    }
  }

  /// Mission step Yes/No tap → record consent + advance to journey
  /// step. Replaces the dots + Next button on the mission page.
  void _pickConsent(bool consent) {
    context.read<WizardBloc>().add(WizardEvent.consentPicked(consent));
    _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
  }

  /// The wizard offers no exchange choice: where the platform allows the
  /// exchange, finishing stages its default (on), applied only if the access
  /// was never set. Settings > Exchange is where the user changes it.
  void _confirmExchange() {
    if (!widget.exchangeAllowed) return;
    context.read<WizardBloc>().add(const WizardEvent.exchangeConfirmed());
  }

  /// Seven taps on the welcome logo unlock the superuser rows of the settings
  /// step, or lock them again and drop what they chose.
  void _toggleSuperuser() {
    final bloc = context.read<WizardBloc>();
    setState(() {
      _superuser = !_superuser;
      if (!_superuser) _networkConsented = false;
    });
    if (_superuser) return;
    bloc.add(const WizardEvent.networkPicked(null));
    bloc.add(const WizardEvent.screenPrivacyPicked(null));
  }

  /// Leaving mainnet asks for consent once; cancelling keeps the previous
  /// network.
  Future<void> _pickNetwork(Environment network) async {
    final bloc = context.read<WizardBloc>();
    if (network != Environment.mainnet && !_networkConsented) {
      final accepted = await confirmDeveloperNetwork(context);
      if (!mounted || !accepted) return;
      _networkConsented = true;
    }
    bloc.add(
      WizardEvent.networkPicked(
        network == Environment.mainnet ? null : network,
      ),
    );
  }

  void _tryFinish(WizardChoices choices) {
    if (_busy || _retryRequired) return;
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
    setState(() => _busy = true);
    _scheduleCompletion();
  }

  void _scheduleCompletion() {
    if (_frameCallbackScheduled || _completionDispatched) return;
    _frameCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCallbackScheduled = false;
      if (!mounted || !_busy || _completionDispatched) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      _completionDispatched = true;
      context.read<WizardBloc>().add(const WizardEvent.completed());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final hPad = Device.screen.width * 0.06;
    final vGap = Device.screen.height * 0.02;

    final isWelcome = _page == WizardPage.welcome;
    final isMission = _page == WizardPage.mission;
    final isLast = _page.isLast;
    return BlocListener<WizardBloc, WizardState>(
      listenWhen: (previous, current) =>
          previous.storageFailure != current.storageFailure &&
          current.storageFailure != null,
      listener: (context, state) {
        setState(() {
          _busy = false;
          _retryRequired = true;
          _completionDispatched = false;
        });
      },
      child: PopScope(
        // Block the actual app pop. The handler below intercepts the
        // gesture and steps the PageView back one page instead — except
        // on page 1, where we silently swallow the pop so the consent
        // collection can't be skipped before `Bull.init` migrations run.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _busy || _retryRequired) return;
          if (!_page.isFirst) {
            _controller.previousPage(
              duration: _pageDuration,
              curve: _pageCurve,
            );
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
              if (isWelcome)
                WelcomeBgPattern(pattern: widget.branding.welcomePattern),
              ExcludeSemantics(
                excluding: _busy || _retryRequired,
                child: ExcludeFocus(
                  excluding: _busy || _retryRequired,
                  child: IgnorePointer(
                    ignoring: _busy || _retryRequired,
                    child: SafeArea(
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
                                    WizardHeader(
                                      logo: widget.branding.headerLogo,
                                      onSkip: () => _tryFinish(c),
                                    ),
                                  Expanded(
                                    child: PageView(
                                      controller: _controller,
                                      onPageChanged: (i) =>
                                          setState(() => _page = _pages[i]),
                                      children: [
                                        WelcomeStep(
                                          logo: widget.branding.welcomeLogo,
                                          logoWidget: WizardNetworkControl(
                                            logo: widget.branding.welcomeLogo,
                                            unlocked: _superuser,
                                            onToggled: _toggleSuperuser,
                                          ),
                                        ),
                                        CustomizeStep(
                                          superuserOptions: _superuser
                                              ? WizardSuperuserOptions(
                                                  screenPrivacy:
                                                      c.screenPrivacy,
                                                  onScreenPrivacyPicked:
                                                      (value) => bloc.add(
                                                        WizardEvent.screenPrivacyPicked(
                                                          value,
                                                        ),
                                                      ),
                                                  network:
                                                      c.network ??
                                                      Environment.mainnet,
                                                  onNetworkPicked: _pickNetwork,
                                                  allowDeveloperNetwork: widget
                                                      .allowDeveloperNetwork,
                                                )
                                              : null,
                                          language: c.language,
                                          defaultCurrency: c.defaultCurrency,
                                          onThemePicked: (m) => bloc.add(
                                            WizardEvent.themePicked(m),
                                          ),
                                          onLanguagePicked: (l) => bloc.add(
                                            WizardEvent.languagePicked(l),
                                          ),
                                          onCurrencyPicked: (code) => bloc.add(
                                            WizardEvent.currencyPicked(code),
                                          ),
                                          backgroundTasks:
                                              widget.backgroundTasksAvailable
                                              ? c.backgroundTasks
                                              : null,
                                          onBackgroundTasksPicked: (value) =>
                                              bloc.add(
                                                WizardEvent.backgroundTasksPicked(
                                                  value,
                                                ),
                                              ),
                                          notificationsAllowed:
                                              state.notificationsAllowed,
                                          notificationsRefused:
                                              state.notificationsRefused,
                                          onNotificationsPicked: (value) =>
                                              bloc.add(
                                                WizardEvent.notificationsPicked(
                                                  value,
                                                ),
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
                                  padding: EdgeInsets.fromLTRB(
                                    hPad,
                                    vGap,
                                    hPad,
                                    hPad,
                                  ),
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
                                                  label: context
                                                      .loc
                                                      .wizardNextButton,
                                                  onPressed: () => _advance(c),
                                                )
                                              : BullButton.primary(
                                                  label: isLast
                                                      ? context
                                                            .loc
                                                            .getStartedButton
                                                      : context
                                                            .loc
                                                            .wizardNextButton,
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
                  ),
                ),
              ),
              if (_busy || _retryRequired)
                Positioned.fill(
                  child: ColoredBox(
                    color: context.appColors.background,
                    child: Center(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_busy) ...[
                              const BullLoader.large(),
                              Text(context.loc.wizardPreparing),
                            ] else ...[
                              Text(
                                SettingsLocalizations.of(context)
                                    .oopsSomethingWentWrong,
                              ),
                              BullButton.primary(
                                label: SettingsLocalizations.of(context)
                                    .statisticsConsentRetry,
                                onPressed: () {
                                  if (_busy) return;
                                  setState(() {
                                    _retryRequired = false;
                                    _busy = true;
                                  });
                                  _scheduleCompletion();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
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
