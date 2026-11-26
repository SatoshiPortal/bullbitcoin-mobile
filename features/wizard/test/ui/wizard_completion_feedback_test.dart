import 'dart:async';

import 'package:bull_ui/bull_ui.dart' show BullLoader;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/ui/screens/wizard_screen.dart';

import 'test_branding.dart';
import 'wizard_test_support.dart';

class BlockingWizardRepository extends FakeWizardRepository {
  final gate = Completer<void>();
  int saves = 0;
  int markers = 0;

  @override
  Future<void> savePending(WizardChoices choices) async {
    saves++;
    pending = choices;
    await gate.future;
  }

  @override
  Future<void> markComplete() async {
    markers++;
  }
}

class RetryWizardRepository extends FakeWizardRepository {
  int saves = 0;
  int markers = 0;

  @override
  Future<void> savePending(WizardChoices choices) async {
    saves++;
    if (saves == 1) throw Exception('private error');
    pending = choices;
  }

  @override
  Future<void> markComplete() async {
    markers++;
  }
}

void main() {
  testWidgets('completion paints accessible feedback before staging once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = BlockingWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: true,
          backgroundTasksAvailable: false,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('Skip'));
    expect(repository.saves, 0);
    await tester.pump();
    expect(find.byType(BullLoader), findsOneWidget);
    expect(find.bySemanticsLabel('Preparing your wallet'), findsOneWidget);
    await tester.pump();
    expect(repository.saves, 1);
    expect(repository.markers, 0);
    repository.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(repository.markers, 1);
    semantics.dispose();
  });

  testWidgets('disposing before the feedback frame does not start storage', (
    tester,
  ) async {
    final repository = BlockingWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: false,
          backgroundTasksAvailable: false,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpWidget(const SizedBox());
    expect(repository.saves, 0);
  });

  testWidgets('pause and resume after starting does not replay storage', (
    tester,
  ) async {
    final repository = BlockingWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: false,
          backgroundTasksAvailable: false,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump();
    expect(repository.saves, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.saves, 1);
    repository.gate.complete();
    await tester.pump();
    expect(repository.markers, 1);
  });

  testWidgets('a suspended feedback frame resumes before starting', (
    tester,
  ) async {
    final repository = BlockingWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: false,
          backgroundTasksAvailable: false,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(repository.saves, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(repository.saves, 1);
    repository.gate.complete();
    await tester.pump();
  });

  testWidgets('a failed save shows a generic error and can be retried', (
    tester,
  ) async {
    final repository = RetryWizardRepository();
    await pumpWizard(
      tester,
      BlocProvider(
        create: (_) => buildWizardBloc(repository, FakePermissions()),
        child: WizardScreen(
          branding: testBranding,
          exchangeAllowed: true,
          backgroundTasksAvailable: false,
        ),
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(repository.saves, 1);
    expect(repository.markers, 0);
    expect(find.text('Oops! Something went wrong'), findsWidgets);
    expect(find.text('private error'), findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        find.ancestor(
          of: find.text('Retry'),
          matching: find.byElementPredicate((element) => element == focused),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Retry'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(repository.saves, 2);
    expect(repository.markers, 1);
    expect(repository.pending?.reportingConsent, isFalse);
  });
}
