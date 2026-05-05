import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/translation_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/customize_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/journey_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/mission_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/welcome_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_dots.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_header.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:flutter/material.dart';

/// 4-page install/upgrade wizard body.
///
/// Pure UI — receives [choices] from a parent that owns the state and
/// reports user picks via [onChange] / [onDone]. Two parents wrap this
/// widget at runtime, selected by `main.dart` based on
/// `WizardGate.isSetupComplete()`:
///
/// 1. **Pre-init upgrade path** — `WizardApp` (a self-contained
///    `MaterialApp`) runs before `Bull.init()` so the user's consent is
///    in prefs before migrations / Sentry init / Drift schema work
///    fires off. Choices stage in SharedPreferences via
///    `WizardGate.savePending` and are flushed to SQLite by
///    `WizardGate.apply` once the locator is up. Back gesture is
///    blocked there to keep the consent collection mandatory.
///
/// 2. **Post-init fresh-install path** — `WizardRouteScreen` (a
///    `GoRoute` target) mounts after `Bull.init()` from the
///    Create/Recover buttons and writes through `SettingsCubit`
///    directly for live theme/language preview. Back gesture is
///    allowed there: cancelling pops the route with `null`, the caller
///    aborts the create/recover, the wizard re-prompts on the next
///    tap (since `markComplete` only fires from Skip/Get started).
///
/// `initState` performs system probes (keyboard locale + brightness)
/// via [WizardChoices.copyWithSilent] so the wizard *displays* sensible
/// defaults without committing them to user settings — only fields the
/// user actively picks via the pickers join `WizardChoices.touched`.
class WizardScreen extends StatefulWidget {
  const WizardScreen({
    super.key,
    required this.choices,
    required this.onChange,
    required this.onDone,
  });

  final WizardChoices choices;
  final ValueChanged<WizardChoices> onChange;
  final VoidCallback onDone;

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

    final c = widget.choices;
    final needsLangUpdate =
        detectedLang != Language.unitedStatesEnglish &&
        c.language == Language.unitedStatesEnglish;
    final needsThemeUpdate = c.themeMode == AppThemeMode.system;
    if (!needsLangUpdate && !needsThemeUpdate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // `copyWithSilent` updates the displayed value WITHOUT marking
      // the field as touched — auto-detected values (brightness +
      // keyboard) shouldn't get committed to user settings unless the
      // user later confirms via the picker. Critical for the upgrade
      // pre-init path where the user's existing language/theme would
      // otherwise be clobbered when they tap Skip.
      var updated = widget.choices;
      if (needsLangUpdate) {
        updated = updated.copyWithSilent(language: detectedLang);
      }
      if (needsThemeUpdate) {
        updated = updated.copyWithSilent(themeMode: detectedTheme);
      }
      widget.onChange(updated);
      if (needsLangUpdate) TranslationWarningBottomSheet.show(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    // Block leaving the mission step until the user explicitly picks Yes/No.
    if (_page == _missionPage && widget.choices.reportingConsent == null) {
      SnackBarUtils.showSnackBar(context, context.loc.wizardMissionRequired);
      return;
    }
    if (_page < _totalSteps - 1) {
      _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
    } else {
      _tryFinish();
    }
  }

  void _tryFinish() {
    if (widget.choices.reportingConsent == null) {
      _controller.animateToPage(
        _missionPage,
        duration: _pageDuration,
        curve: _pageCurve,
      );
      SnackBarUtils.showSnackBar(context, context.loc.wizardMissionRequired);
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.choices;
    final isLast = _page == _totalSteps - 1;
    final hPad = Device.screen.width * 0.06;
    final vGap = Device.screen.height * 0.02;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Column(
          children: [
            WizardHeader(onSkip: _tryFinish),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  WelcomeStep(stepIndex: 0, totalSteps: _totalSteps),
                  CustomizeStep(
                    stepIndex: 1,
                    totalSteps: _totalSteps,
                    choices: c,
                    onChange: widget.onChange,
                  ),
                  MissionStep(
                    stepIndex: _missionPage,
                    totalSteps: _totalSteps,
                    consent: c.reportingConsent,
                    onChanged: (v) => widget.onChange(
                      c.copyWith(reportingConsent: ConsentValue(v)),
                    ),
                  ),
                  JourneyStep(stepIndex: 3, totalSteps: _totalSteps),
                ],
              ),
            ),
            SizedBox(height: vGap),
            WizardDots(count: _totalSteps, index: _page),
            SizedBox(height: vGap),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
              child: SizedBox(
                width: double.infinity,
                child: BBButton.big(
                  label: isLast
                      ? context.loc.getStartedButton
                      : context.loc.wizardNextButton,
                  onPressed: _advance,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
