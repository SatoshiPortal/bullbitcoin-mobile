import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/domain/decoded_labels.dart';
import 'package:bb_mobile/features/labels/domain/formatted_labels.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/label_failure.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements LabelsRepositoryPort {}

class _MockWalletFreeze extends Mock implements WalletFreezePort {}

/// The real codec: these tests are about which *reason* survives the trip to
/// the caller, and stubbing the converter would skip the mapping under test.
class _RealCodecConverter implements LabelsConverterPort {
  final _codec = Bip329LabelsCodec();

  @override
  DecodedLabels convertFrom(FormattedLabels labels) =>
      _codec.decode((labels as FormattedLabelsBIP329).jsonl);

  @override
  FormattedLabels convertTo({
    required format,
    required labels,
    frozen = const [],
  }) => throw UnimplementedError();
}

String _validLine() =>
    jsonEncode({'type': 'tx', 'ref': 'a' * 64, 'label': 'coffee'});

void main() {
  late ImportLabelsUsecase usecase;
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
    usecase = ImportLabelsUsecase(
      labelRepository: repository,
      labelConverter: _RealCodecConverter(),
      walletFreeze: _MockWalletFreeze(),
    );
    when(() => repository.storeAll(any())).thenAnswer((_) async {});
  });

  Future<Result<int, LabelFailure>> import(String jsonl) =>
      usecase.call(FormattedLabelsBIP329(jsonl: jsonl));

  test('imports a valid file', () async {
    final result = await import(_validLine());

    expect((result as Ok<int, LabelFailure>).value, 1);
  });

  // Each of these used to be a bare `throw 'string'` that the cubit turned
  // into LabelUnexpectedFailure — so a wrong file, a huge file and an empty
  // file all told the user "Oops something went wrong" and nothing else.
  group('a bad file says which way it is bad', () {
    test('too large', () async {
      final huge = 'x' * (Bip329LabelsCodec.maxImportBytes + 1);

      final result = await import(huge);

      switch (result) {
        case Ok():
          fail('an oversized file must not be reported as imported');
        case Err(:final failure):
          expect(failure, isA<LabelsFileTooLargeFailure>());
          expect(
            (failure as LabelsFileTooLargeFailure).maxBytes,
            Bip329LabelsCodec.maxImportBytes,
          );
      }
    });

    test('too large is measured in bytes, not UTF-16 code units: a file of '
        'non-ASCII labels used to slip past the stated limit', () async {
      // Just under the limit in code units, comfortably over it in UTF-8.
      final multibyte = '\u00e9' * (Bip329LabelsCodec.maxImportBytes - 10);

      final result = await import(multibyte);

      expect(
        (result as Err<int, LabelFailure>).failure,
        isA<LabelsFileTooLargeFailure>(),
      );
    });

    test('not a BIP-329 file', () async {
      final result = await import('this is not json at all');

      expect(
        (result as Err<int, LabelFailure>).failure,
        isA<LabelsFileUnreadableFailure>(),
      );
    });

    test('uses a name the app reserves', () async {
      // This used to throw LabelValidationException, which is not a
      // LabelsImportException — so it fell past the typed handler into the
      // catch-all and read "Oops something went wrong", the exact outcome
      // this change exists to remove.
      final reserved = jsonEncode({
        'type': 'tx',
        'ref': 'a' * 64,
        'label': LabelSystem.payjoin.label,
      });

      final result = await import(reserved);

      switch (result) {
        case Ok():
          fail('a reserved label name must not be reported as imported');
        case Err(:final failure):
          expect(failure, isA<LabelsFileReservedNameFailure>());
          expect(failure, isNot(isA<LabelUnexpectedFailure>()));
      }
    });

    test('carries an entry the app cannot accept', () async {
      // A bad ref survives decode() — the codec does not validate references
      // — and is rejected by LabelEntity inside the repository, which throws
      // LabelValidationException. That is not a LabelsImportException, so it
      // used to fall past the typed handler into the catch-all and read
      // "Oops something went wrong".
      when(
        () => repository.storeAll(any()),
      ).thenThrow(LabelValidationException('Invalid txid: not-a-txid'));

      final result = await import(_validLine());

      switch (result) {
        case Ok():
          fail('an invalid reference must not be reported as imported');
        case Err(:final failure):
          expect(failure, isA<LabelsFileInvalidEntryFailure>());
          expect(failure, isNot(isA<LabelUnexpectedFailure>()));
          // The exception names the offending reference, which can be an
          // xpub. It is logged, never carried.
          expect(failure.logMessage, isNull);
      }
    });

    test('parses but holds no labels', () async {
      final result = await import('');

      // An empty string is rejected before parsing on some codec paths and
      // after on others; either way it must be its own answer, not the
      // catch-all.
      final failure = (result as Err<int, LabelFailure>).failure;
      expect(
        failure,
        anyOf(
          isA<LabelsFileUnreadableFailure>(),
          isA<LabelsFileEmptyFailure>(),
        ),
      );
      expect(failure, isNot(isA<LabelUnexpectedFailure>()));
    });
  });

  test('a store failure is the catch-all, and carries no reason: the label '
      'content is the user\'s own words', () async {
    when(
      () => repository.storeAll(any()),
    ).thenThrow(Exception('drift: rent to Alice Smith'));

    final result = await import(_validLine());

    switch (result) {
      case Ok():
        fail('a failed store must not be reported as imported');
      case Err(:final failure):
        expect(failure, isA<LabelUnexpectedFailure>());
        expect(failure.logMessage, isNull);
    }
  });
}
