import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/presentation/bloc/wizard_bloc.dart';

import 'wizard_test_support.dart';

class CompletionRepository extends FakeWizardRepository {
  final gate = Completer<void>();
  final saved = <WizardChoices>[];
  int markers = 0;
  bool failSave = false;
  bool failMarker = false;

  @override
  Future<void> savePending(WizardChoices choices) async {
    saved.add(choices);
    await gate.future;
    if (failSave) throw Exception('save');
  }

  @override
  Future<void> markComplete() async {
    markers++;
    if (failMarker) throw Exception('marker');
  }
}

void main() {
  testWidgets('completion is single flight and captures false and exchange', (
    tester,
  ) async {
    final repository = CompletionRepository();
    final bloc = buildWizardBloc(repository, FakePermissions());
    addTearDown(bloc.close);
    bloc.add(const WizardEvent.consentPicked(false));
    bloc.add(const WizardEvent.exchangeConfirmed());
    bloc.add(const WizardEvent.completed());
    bloc.add(const WizardEvent.completed());
    await tester.pump();
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.reportingConsent, isFalse);
    expect(
      repository.saved.single.touched,
      contains(WizardField.exchangeAccess),
    );
    expect(repository.markers, 0);
    repository.gate.complete();
    await tester.pump();
    expect(repository.markers, 1);
    expect(bloc.state.finished, isTrue);
    bloc.add(const WizardEvent.completed());
    await tester.pump();
    expect(repository.saved, hasLength(1));
    expect(repository.markers, 1);
  });

  testWidgets('missing consent blocks completion', (tester) async {
    final repository = CompletionRepository();
    final bloc = buildWizardBloc(repository, FakePermissions());
    addTearDown(bloc.close);
    bloc.add(const WizardEvent.completed());
    await tester.pump();
    expect(repository.saved, isEmpty);
    expect(repository.markers, 0);
  });

  for (final failsSave in [true, false]) {
    testWidgets('retry preserves snapshot after save failure: $failsSave', (
      tester,
    ) async {
      final repository = CompletionRepository()
        ..failSave = failsSave
        ..failMarker = !failsSave;
      repository.gate.complete();
      final bloc = buildWizardBloc(repository, FakePermissions());
      addTearDown(bloc.close);
      bloc.add(const WizardEvent.consentPicked(false));
      bloc.add(const WizardEvent.exchangeConfirmed());
      bloc.add(const WizardEvent.completed());
      await tester.pump();
      expect(bloc.state.storageFailure, isNotNull);
      expect(repository.markers, failsSave ? 0 : 1);
      repository.failSave = false;
      repository.failMarker = false;
      bloc.add(const WizardEvent.consentPicked(true));
      bloc.add(const WizardEvent.completed());
      await tester.pump();
      expect(bloc.state.finished, isTrue);
      expect(repository.saved, hasLength(failsSave ? 2 : 1));
      expect(
        repository.saved.every((c) => c.reportingConsent == false),
        isTrue,
      );
      expect(repository.markers, failsSave ? 1 : 2);
    });
  }
}
