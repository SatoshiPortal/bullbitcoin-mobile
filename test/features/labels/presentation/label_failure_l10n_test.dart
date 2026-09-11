import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/note_violation_to_label_failure.dart';
import 'package:bb_mobile/features/labels/presentation/label_failure_l10n.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Labels hold the user's own words about their money — counterparty names,
/// what a transaction was for. A reason quoting a rejected file can echo
/// them straight back, so no arm may render one.
const _rawReason =
    'FormatException: line 3: {"type":"tx","label":"rent to Alice Smith"}';

final _everyFailure = <LabelFailure>[
  const LabelNoteTooLongFailure(maxLength: 50, logMessage: _rawReason),
  const LabelNoteForbiddenCharacterFailure(
    character: '/',
    logMessage: _rawReason,
  ),
  const LabelsFileTooLargeFailure(maxBytes: 1048576, logMessage: _rawReason),
  const LabelsFileUnreadableFailure(_rawReason),
  const LabelsFileEmptyFailure(_rawReason),
  const LabelsFileReservedNameFailure(_rawReason),
  const LabelsExportFailure(_rawReason),
  const LabelUnexpectedFailure(_rawReason),
];

Future<String> _translate(WidgetTester tester, LabelFailure failure) async {
  late String message;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          message = failure.toTranslated(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return message;
}

void main() {
  group('LabelFailureL10n.toTranslated', () {
    for (final failure in _everyFailure) {
      testWidgets('${failure.runtimeType} resolves to a user-safe message', (
        tester,
      ) async {
        final message = await _translate(tester, failure);

        expect(
          message,
          isNotEmpty,
          reason: 'the .arb key for ${failure.runtimeType} resolved to nothing',
        );
        expect(message, isNot(contains(_rawReason)));
        expect(message, isNot(contains('FormatException')));
        // The user's own label content, quoted by the parse error.
        expect(message, isNot(contains('Alice Smith')));
      });
    }

    // The point of the extra variants: an import can fail for reasons the
    // user can act on, and they used to be indistinguishable.
    testWidgets('the three import failures read differently from each other '
        'and from the catch-all', (tester) async {
      final messages = <String>{
        await _translate(
          tester,
          const LabelsFileTooLargeFailure(maxBytes: 1024 * 1024),
        ),
        await _translate(tester, const LabelsFileUnreadableFailure()),
        await _translate(tester, const LabelsFileEmptyFailure()),
        await _translate(tester, const LabelUnexpectedFailure()),
      };

      expect(messages, hasLength(4));
    });

    testWidgets('a note failure names the limit and the character, so the '
        'user can fix it', (tester) async {
      final tooLong = await _translate(
        tester,
        const LabelNoteTooLongFailure(maxLength: 50),
      );
      final forbidden = await _translate(
        tester,
        const LabelNoteForbiddenCharacterFailure(character: '/'),
      );

      expect(tooLong, contains('50'));
      expect(forbidden, contains('/'));
    });

    testWidgets('an invisible forbidden character is named, not shown: '
        'interpolating a tab renders nothing at all', (tester) async {
      for (final invisible in ['\t', '\n', '\r']) {
        final message = await _translate(
          tester,
          LabelNoteForbiddenCharacterFailure(character: invisible),
        );

        expect(message.trim(), isNotEmpty);
        // Not the interpolating message, which would end mid-sentence.
        expect(message, isNot(endsWith('character ')));
      }
    });

    testWidgets('a visible forbidden character is still shown', (tester) async {
      final message = await _translate(
        tester,
        const LabelNoteForbiddenCharacterFailure(character: '/'),
      );

      expect(message, contains('/'));
    });

    testWidgets('the size limit is rendered readably, not as a byte count', (
      tester,
    ) async {
      final message = await _translate(
        tester,
        const LabelsFileTooLargeFailure(maxBytes: 1024 * 1024),
      );

      expect(message, contains('1 MiB'));
      expect(message, isNot(contains('1048576')));
    });
  });

  group('mapNoteViolationToLabelFailure', () {
    test('carries the limit through for the message', () {
      final failure = mapNoteViolationToLabelFailure(
        const NoteTooLong(maxLength: 50),
      );

      expect((failure as LabelNoteTooLongFailure).maxLength, 50);
    });

    test('carries the character through — it is the user\'s own input', () {
      final failure = mapNoteViolationToLabelFailure(
        const NoteForbiddenCharacter('/'),
      );

      expect((failure as LabelNoteForbiddenCharacterFailure).character, '/');
    });

    test('never carries a logMessage: a broken input rule is not an incident '
        'to log, and there is no raw reason to leak', () {
      expect(
        mapNoteViolationToLabelFailure(
          const NoteTooLong(maxLength: 50),
        ).logMessage,
        isNull,
      );
      expect(
        mapNoteViolationToLabelFailure(
          const NoteForbiddenCharacter('/'),
        ).logMessage,
        isNull,
      );
    });
  });
}
