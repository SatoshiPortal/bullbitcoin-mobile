import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/presentation/portable_backup_cubit.dart';
import 'package:bb_mobile/features/portable_backup/ui/portable_backup_prototype_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

import '../support/portable_backup_fake.dart';

const _privacyChannel = MethodChannel('com.flutterplaza.no_screenshot_methods');

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, (_) async => true);
    ScreenCaptureProtection.instance.enabledByUser = true;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_privacyChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('platform refusal never exposes the secret input', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _privacyChannel,
      (_) async => false,
    );
    final cubit = PortableBackupFake().cubit();
    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('portable-words')), findsNothing);
    expect(find.byKey(const ValueKey('portable-fetch')), findsNothing);
    await _finish(tester, cubit);
  });

  testWidgets(
    'metadata entry after completed vault fetch preserves reentered words',
    (tester) async {
      final repository = PortableBackupFake()
        ..fetchPending =
            Completer<Result<PortableBackupFetch, PortableBackupFailure>>();
      final cubit = repository.cubit();
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();
      final words = _wordsField();
      await tester.enterText(words, testWords);
      await tester.pumpAndSettle();
      final fetch = find.byKey(const ValueKey('portable-fetch'));
      await tester.ensureVisible(fetch);
      await tester.tap(fetch);
      await tester.pump();
      expect(cubit.state.busy, isTrue);
      repository.fetchPending!.complete(Ok(repository.recovered));
      await tester.pumpAndSettle();
      expect(cubit.state.recovered, isNotNull);
      expect(tester.widget<EditableText>(words).controller.text, isEmpty);

      await tester.ensureVisible(words);
      await tester.enterText(words, testWords);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(words).controller.text, testWords);
      final file = find.descendant(
        of: find.byKey(const ValueKey('portable-metadata-file')),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(file);
      await tester.enterText(file, base64Encode(repository.files.metadata));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(words).controller.text, testWords);
      expect(
        tester.widget<EditableText>(file).controller.text,
        base64Encode(repository.files.metadata),
      );
      final open = find.byKey(const ValueKey('portable-open-metadata'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(cubit.state.metadataOpened, isTrue);
      expect(tester.widget<EditableText>(words).controller.text, isEmpty);
      expect(tester.widget<EditableText>(file).controller.text, isEmpty);
      await _finish(tester, cubit);
    },
  );

  testWidgets(
    'changing metadata input clears the previous unlock confirmation',
    (tester) async {
      final repository = PortableBackupFake();
      final cubit = repository.cubit();
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();
      await tester.enterText(_wordsField(), testWords);
      final file = find.descendant(
        of: find.byKey(const ValueKey('portable-metadata-file')),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(file);
      await tester.enterText(file, base64Encode(repository.files.metadata));
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('portable-open-metadata'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portable-metadata-opened')),
        findsOneWidget,
      );
      await tester.ensureVisible(file);
      await tester.enterText(file, 'a different file');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('portable-metadata-opened')),
        findsNothing,
      );
      expect(
        tester.widget<EditableText>(file).controller.text,
        'a different file',
      );
      await _finish(tester, cubit);
    },
  );

  testWidgets(
    'a failed copy clears prior success without calling the file invalid',
    (tester) async {
      var failCopy = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData' && failCopy) {
            throw PlatformException(code: 'clipboard-unavailable');
          }
          return null;
        },
      );
      final cubit = PortableBackupFake().cubit();
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();
      await tester.enterText(_wordsField(), testWords);
      await tester.pumpAndSettle();
      final fetch = find.byKey(const ValueKey('portable-fetch'));
      await tester.ensureVisible(fetch);
      await tester.tap(fetch);
      await tester.pumpAndSettle();
      final copy = find.text('Copy encrypted vault file (base64)');
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.text('Encrypted file copied'), findsOneWidget);
      failCopy = true;
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.text('Encrypted file copied'), findsNothing);
      expect(
        find.text('This backup file is invalid or incompatible.'),
        findsNothing,
      );
      final context = tester.element(
        find.byType(PortableBackupPrototypeScreen),
      );
      expect(
        find.text(AppLocalizations.of(context).oopsSomethingWentWrong),
        findsOneWidget,
      );
      await _finish(tester, cubit);
    },
  );

  testWidgets(
    'secret input never builds before protection succeeds or after failure',
    (tester) async {
      final protection = Completer<Object?>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _privacyChannel,
        (call) => call.method == 'screenshotOff'
            ? protection.future
            : Future.value(true),
      );
      final repository = PortableBackupFake();
      final cubit = repository.cubit();
      await tester.pumpWidget(_app(cubit));
      await tester.pump();
      expect(find.byKey(const ValueKey('portable-words')), findsNothing);
      protection.completeError(
        PlatformException(code: 'protection-unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('portable-words')), findsNothing);
      expect(find.byKey(const ValueKey('portable-fetch')), findsNothing);
      expect(repository.fetchSession, isNull);
      await _finish(tester, cubit);
    },
  );

  testWidgets(
    'submit clears words; background cancellation rejects late recovery',
    (tester) async {
      final repository = PortableBackupFake()
        ..fetchPending =
            Completer<Result<PortableBackupFetch, PortableBackupFailure>>();
      final cubit = repository.cubit();
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();
      final field = _wordsField();
      await tester.enterText(field, testWords);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).obscureText, isTrue);
      expect(tester.widget<EditableText>(field).enableSuggestions, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('portable-fetch')));
      await tester.tap(find.byKey(const ValueKey('portable-fetch')));
      await tester.pump();
      expect(cubit.state.busy, isTrue);
      expect(tester.widget<EditableText>(field).controller.text, isEmpty);
      expect(cubit.state.recovered, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(repository.fetchSession!.isCancelled, isTrue);
      expect(find.byKey(const ValueKey('portable-words')), findsNothing);
      repository.fetchPending!.complete(Ok(repository.recovered));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.recovered, isNull);
      expect(
        tester.widget<EditableText>(_wordsField()).controller.text,
        isEmpty,
      );
      expect(find.text('public vault descriptor'), findsNothing);
      await _finish(tester, cubit);
    },
  );

  testWidgets('backgrounding also discards a pending derived password', (
    tester,
  ) async {
    final words = Completer<Result<String, PortableBackupFailure>>();
    final repository = PortableBackupFake();
    final cubit = repository.cubit();
    await tester.pumpWidget(_app(cubit, derive: () => words.future));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Derive demo backup words'));
    await tester.tap(find.text('Derive demo backup words'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    words.complete(const Ok(testWords));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(_wordsField()).controller.text, isEmpty);
    expect(find.text(testWords), findsNothing);
    expect(cubit.state.recovered, isNull);
    await _finish(tester, cubit);
  });
}

Finder _wordsField() => find.descendant(
  of: find.byKey(const ValueKey('portable-words')),
  matching: find.byType(EditableText),
);

Widget _app(
  PortableBackupCubit cubit, {
  Future<Result<String, PortableBackupFailure>> Function()? derive,
}) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider.value(
    value: cubit,
    child: PortableBackupPrototypeScreen(deriveDemoWords: derive),
  ),
);

Future<void> _finish(WidgetTester tester, PortableBackupCubit cubit) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await cubit.close();
}
