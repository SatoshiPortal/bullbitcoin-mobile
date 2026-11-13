import 'dart:io';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/bloc/wizard_bloc.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

class _Preferences extends Mock implements SharedPreferences {}

void main() {
  for (final throwsException in [true, false]) {
    test(
      'completion failure (${throwsException ? 'exception' : 'rejected write'}) allows retry',
      () async {
        final preferences = _Preferences();
        var failCompletion = true;
        int? completedVersion;
        when(() => preferences.remove(any())).thenAnswer((_) async => true);
        when(
          () => preferences.getInt(any()),
        ).thenAnswer((_) => completedVersion);
        when(
          () => preferences.setInt(
            'wizard_completed_version',
            kCurrentWizardVersion,
          ),
        ).thenAnswer((_) async {
          if (failCompletion) {
            if (throwsException) throw const FileSystemException('Unavailable');
            return false;
          }
          completedVersion = kCurrentWizardVersion;
          return true;
        });
        final repository = WizardRepositoryImpl(
          WizardLocalDatasourceImpl(getPreferences: () async => preferences),
        );
        final bloc = WizardBloc(
          savePending: SavePendingWizardChoicesUsecase(repository: repository),
          markComplete: MarkWizardCompleteUsecase(repository: repository),
        );
        addTearDown(bloc.close);
        final failed = bloc.stream.firstWhere((state) => state.failure != null);
        bloc.add(const WizardEvent.completed());
        final failure = await failed;
        expect(failure.failure, isA<WizardSaveFailure>());
        expect(failure.saving, isFalse);
        expect(failure.finished, isFalse);
        expect(completedVersion, isNull);

        failCompletion = false;
        final finished = bloc.stream.firstWhere((state) => state.finished);
        bloc.add(const WizardEvent.completed());
        final success = await finished;
        expect(success.saving, isFalse);
        expect(success.failure, isNull);
        expect(await repository.isComplete(), isTrue);
      },
    );
  }
}
