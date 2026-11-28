import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source contract for the three frames the startup campaign reads:
/// `onboarding_loading_frame`, `app_first_frame` and
/// `startup_gate_success_frame`. Each label must stay attached to the frame it
/// names — the launch-to-first-frame ordering has no other observable proof in
/// a widget test.
void main() {
  final String bootstrap = File('lib/bootstrap.dart').readAsStringSync();
  final String splash = File(
    'features/onboarding/lib/src/ui/screens/onboarding_splash.dart',
  ).readAsStringSync();
  final String gate = File(
    'features/startup/lib/src/ui/app_startup_widget.dart',
  ).readAsStringSync();

  test('the watch starts as soon as the binding exists', () {
    final int binding = bootstrap.indexOf(
      'WidgetsFlutterBinding.ensureInitialized();',
    );
    final int start = bootstrap.indexOf('StartupBench.start();');
    final int wizard = bootstrap.indexOf(
      'final wizard = WizardFeature.mount();',
    );

    expect(binding, greaterThanOrEqualTo(0));
    expect(start, greaterThan(binding));
    expect(wizard, greaterThan(start));
  });

  test('app_first_frame is marked in the first-frame post-frame callback', () {
    final int refresh = bootstrap.indexOf(
      'void _refreshDiagnosticContextAfterFirstFrame() {',
    );
    final int mark = bootstrap.indexOf(
      "StartupBench.markOnce('app_first_frame')",
    );
    final int diagnosticRefresh = bootstrap.indexOf(
      'log.refreshDiagnosticContext()',
      refresh,
    );

    expect(refresh, greaterThanOrEqualTo(0));
    expect(mark, greaterThan(refresh));
    expect(
      mark,
      lessThan(diagnosticRefresh),
      reason: 'the frame is timed before the diagnostic refresh it triggers',
    );
    expect(
      bootstrap.substring(refresh, mark),
      contains('addPostFrameCallback'),
      reason: 'the label belongs to the frame that has just been painted',
    );
  });

  test('the loading and ready splashes mark one frame each', () {
    expect(
      splash,
      contains(
        "loading ? 'onboarding_loading_frame' : 'onboarding_ready_frame'",
      ),
    );
    final int build = splash.indexOf('Widget build(BuildContext context) {');
    final int mark = splash.indexOf("StartupBench.markOnce(");
    expect(mark, greaterThan(build));
    expect(splash.substring(build, mark), contains('addPostFrameCallback'));
  });

  test('the gate marks success before choosing the PIN or app screen', () {
    final int mark = gate.indexOf(
      "StartupBench.markOnce('startup_gate_success_frame')",
    );
    final int pinChoice = gate.indexOf('if (state.isPinCodeSet)');
    final int app = gate.indexOf('return widget.app;');

    expect(mark, greaterThanOrEqualTo(0));
    expect(mark, lessThan(pinChoice));
    expect(pinChoice, lessThan(app));
    expect(
      gate.substring(gate.indexOf('AppStartupSuccess'), mark),
      contains('addPostFrameCallback'),
    );
    // The gate still substitutes the splash immediately, with no crossfade.
    expect(gate, isNot(contains('AnimatedSwitcher')));
  });

  test('the bench writes fixed labels only, and only outside release', () {
    final String bench = File('packages/bull_logger/lib/startup_bench.dart')
        .readAsStringSync();

    expect(bench, contains('if (kReleaseMode) return;'));
    expect(bench, contains(r"'BULL_STARTUP_BENCH v=1 ph=$phase"));
  });
}
