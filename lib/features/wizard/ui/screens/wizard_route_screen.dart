import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wizard/ui/screens/wizard_screen.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/wizard_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// In-app wrapper around [WizardScreen] mounted as a full-screen route.
///
/// Differs from the now-removed pre-init `WizardApp` wrapper in that the
/// locator is already initialized by the time this widget mounts, so each
/// choice is committed immediately through `SettingsCubit` (live preview
/// of theme + language + currency). On `onDone` we just persist the
/// completion marker and pop — no prefs staging needed.
///
/// `PopScope(canPop: false)` blocks the Android back button so the only
/// way to leave the wizard is via Skip / Get Started, which both route
/// through `_finish` after the consent gate is satisfied.
class WizardRouteScreen extends StatefulWidget {
  const WizardRouteScreen({super.key});

  @override
  State<WizardRouteScreen> createState() => _WizardRouteScreenState();
}

class _WizardRouteScreenState extends State<WizardRouteScreen> {
  late WizardChoices _choices;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>().state.storedSettings;
    _choices = WizardChoices(
      language: settings?.language ?? Language.unitedStatesEnglish,
      themeMode: settings?.themeMode ?? AppThemeMode.system,
      defaultCurrency: settings?.currencyCode ?? 'USD',
      // Force re-consent each time the wizard shows.
      reportingConsent: null,
    );
  }

  void _update(WizardChoices next) {
    final cubit = context.read<SettingsCubit>();
    // Only commit fields the user actively picked. Auto-detection
    // (brightness, keyboard) flows in via `copyWithSilent`, which
    // leaves the touched set unchanged so settings don't get clobbered
    // by values the user merely *saw*.
    if (next.touched.contains(WizardField.themeMode) &&
        next.themeMode != _choices.themeMode &&
        next.themeMode != AppThemeMode.system) {
      cubit.changeThemeMode(next.themeMode);
    }
    if (next.touched.contains(WizardField.language) &&
        next.language != _choices.language) {
      cubit.changeLanguage(next.language);
    }
    if (next.touched.contains(WizardField.defaultCurrency) &&
        next.defaultCurrency != _choices.defaultCurrency) {
      cubit.changeCurrency(next.defaultCurrency);
    }
    if (next.touched.contains(WizardField.reportingConsent) &&
        next.reportingConsent != _choices.reportingConsent &&
        next.reportingConsent != null) {
      cubit.toggleErrorReporting(next.reportingConsent!);
    }
    setState(() => _choices = next);
  }

  Future<void> _onDone() async {
    await WizardGate.markComplete();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: WizardScreen(
        choices: _choices,
        onChange: _update,
        onDone: _onDone,
      ),
    );
  }
}
