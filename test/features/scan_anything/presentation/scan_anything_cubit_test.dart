import 'dart:async';

import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_history.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/decode_bbqr_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/identify_scanned_content_usecase.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/import_scanned_labels_usecase.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_cubit.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

const _txidContent = TransactionIdContent(txid: 'txid');

class FakeIdentify implements IdentifyScannedContentUsecase {
  final inputs = <String>[];
  Future<Result<ScannedContent, ScanAnythingFailure>> Function() answer =
      () async => const Ok(_txidContent);

  @override
  Future<Result<ScannedContent, ScanAnythingFailure>> execute(String input) {
    inputs.add(input);
    return answer();
  }
}

class FakeImportLabels implements ImportScannedLabelsUsecase {
  final inputs = <String>[];
  Result<int, ScanAnythingFailure> answer = const Ok(2);

  @override
  Future<Result<int, ScanAnythingFailure>> execute(String jsonl) async {
    inputs.add(jsonl);
    return answer;
  }
}

void main() {
  late FakeIdentify identify;
  late FakeImportLabels importLabels;
  late ScanHistory history;
  late String? decodedImage;

  ScanAnythingCubit build() => ScanAnythingCubit(
    identifyScannedContentUsecase: identify,
    decodeBbqrUsecase: DecodeBbqrUsecase(join: (_) async => [1, 255]),
    importScannedLabelsUsecase: importLabels,
    decodeImage: (_) async => decodedImage,
    history: history,
    now: () => DateTime(2026),
  );

  setUp(() {
    identify = FakeIdentify();
    importLabels = FakeImportLabels();
    history = ScanHistory();
    decodedImage = null;
  });

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'a result goes to the history and survives a reset',
    build: build,
    act: (cubit) async {
      await cubit.onScanned('one');
      cubit.reset();
    },
    verify: (cubit) {
      expect(cubit.state.content, isNull);
      expect(cubit.state.history.single.content, same(_txidContent));
      expect(cubit.state.history.single.time, DateTime(2026));
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'a secret never goes to the history',
    build: build,
    act: (cubit) async {
      identify.answer = () async => const Ok(RecoveryPhraseContent());
      await cubit.onScanned('words');
    },
    verify: (cubit) {
      expect(cubit.state.history, isEmpty);
      expect(history.entries, isEmpty);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'a history entry opens its result without a new identification',
    build: build,
    act: (cubit) async {
      await cubit.onScanned('one');
      cubit.reset();
      cubit.openHistoryEntry(cubit.state.history.single);
    },
    verify: (cubit) {
      expect(identify.inputs, ['one']);
      expect(cubit.state.content, same(_txidContent));
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'clearing empties the history',
    build: build,
    act: (cubit) async {
      await cubit.onScanned('one');
      cubit.reset();
      cubit.clearHistory();
    },
    verify: (cubit) {
      expect(cubit.state.history, isEmpty);
      expect(history.entries, isEmpty);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'an image with a code is identified',
    build: build,
    act: (cubit) {
      decodedImage = 'from-image';
      return cubit.onImagePicked('/tmp/code.png');
    },
    verify: (cubit) {
      expect(identify.inputs, ['from-image']);
      expect(cubit.state.content, isNotNull);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'an image without a code is not recognized',
    build: build,
    act: (cubit) => cubit.onImagePicked('/tmp/photo.png'),
    verify: (cubit) {
      expect(identify.inputs, isEmpty);
      expect(cubit.state.failure, isA<ScanAnythingUnrecognizedFailure>());
      expect(cubit.state.isIdentifying, isFalse);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'labels are imported once, on request only',
    build: build,
    act: (cubit) async {
      identify.answer = () async =>
          const Ok(LabelsExportContent(jsonl: 'lines', count: 2));
      await cubit.onScanned('lines');
      expect(importLabels.inputs, isEmpty);
      await cubit.importLabels();
      await cubit.importLabels();
    },
    verify: (cubit) {
      expect(importLabels.inputs, ['lines']);
      expect(cubit.state.importedLabelCount, 2);
      expect(cubit.state.content, isNotNull);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'a failed label import keeps the result open',
    build: build,
    act: (cubit) async {
      identify.answer = () async =>
          const Ok(LabelsExportContent(jsonl: 'lines', count: 2));
      importLabels.answer = const Err(ScanAnythingLabelsImportFailure());
      await cubit.onScanned('lines');
      await cubit.importLabels();
    },
    verify: (cubit) {
      expect(cubit.state.failure, isA<ScanAnythingLabelsImportFailure>());
      expect(cubit.state.content, isA<LabelsExportContent>());
      expect(cubit.state.importedLabelCount, isNull);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'importing does nothing for other content',
    build: build,
    act: (cubit) async {
      await cubit.onScanned('txid');
      await cubit.importLabels();
    },
    verify: (cubit) => expect(importLabels.inputs, isEmpty),
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'a scan is identified',
    build: build,
    act: (cubit) => cubit.onScanned('scanned'),
    verify: (cubit) {
      expect(identify.inputs, ['scanned']);
      expect(cubit.state.content, same(_txidContent));
      expect(cubit.state.isIdentifying, isFalse);
      expect(cubit.state.failure, isNull);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'pasted text is identified on request',
    build: build,
    act: (cubit) async {
      cubit.updateInput('pasted');
      expect(cubit.state.rawInput, 'pasted');
      await cubit.identify();
    },
    verify: (cubit) {
      expect(identify.inputs, ['pasted']);
      expect(cubit.state.rawInput, 'pasted');
      expect(cubit.state.content, isNotNull);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'a failure keeps the input and a new input clears the failure',
    build: build,
    act: (cubit) async {
      identify.answer = () async =>
          const Err(ScanAnythingUnrecognizedFailure());
      cubit.updateInput('hello');
      await cubit.identify();
      expect(cubit.state.failure, isA<ScanAnythingUnrecognizedFailure>());
      expect(cubit.state.rawInput, 'hello');
      cubit.updateInput('hello2');
    },
    verify: (cubit) {
      expect(cubit.state.failure, isNull);
      expect(cubit.state.content, isNull);
    },
  );

  for (final secret in const <ScannedContent>[
    RecoveryPhraseContent(),
    PrivateKeyContent(),
  ]) {
    blocTest<ScanAnythingCubit, ScanAnythingState>(
      'a ${secret.runtimeType} clears the input',
      build: build,
      act: (cubit) async {
        identify.answer = () async => Ok(secret);
        cubit.updateInput('secret words');
        await cubit.identify();
      },
      verify: (cubit) {
        expect(cubit.state.rawInput, isEmpty);
        expect(cubit.state.content, same(secret));
      },
    );
  }

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'scans are ignored while identifying and while a result is open',
    build: build,
    act: (cubit) async {
      final pending = Completer<Result<ScannedContent, ScanAnythingFailure>>();
      identify.answer = () => pending.future;

      final first = cubit.onScanned('one');
      await cubit.onScanned('two');
      cubit.updateInput('typed');
      expect(cubit.state.isIdentifying, isTrue);

      pending.complete(const Ok(_txidContent));
      await first;
      await cubit.onScanned('three');
      await cubit.identify();
    },
    verify: (cubit) {
      expect(identify.inputs, ['one']);
      expect(cubit.state.rawInput, isEmpty);
    },
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'reset permits a new scan',
    build: build,
    act: (cubit) async {
      await cubit.onScanned('one');
      cubit.reset();
      expect(cubit.state.content, isNull);
      await cubit.onScanned('two');
    },
    verify: (cubit) => expect(identify.inputs, ['one', 'two']),
  );

  blocTest<ScanAnythingCubit, ScanAnythingState>(
    'BBQr parts show progress and the joined data is identified',
    build: build,
    act: (cubit) async {
      await cubit.onScanned(r'B$2T0201BBBB');
      expect(cubit.state.multipartReceived, 1);
      expect(cubit.state.multipartTotal, 2);
      expect(identify.inputs, isEmpty);
      await cubit.onScanned(r'B$2T0200AAAA');
    },
    verify: (cubit) {
      expect(identify.inputs, ['01ff']);
      expect(cubit.state.content, isNotNull);
    },
  );
}
