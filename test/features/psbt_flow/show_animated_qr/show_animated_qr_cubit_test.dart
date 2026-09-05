import 'dart:async';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_flow/domain/generate_psbt_qr_parts_usecase.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:bb_mobile/features/psbt_flow/domain/psbt_qr_encoder_port.dart';
import 'package:bb_mobile/features/psbt_flow/show_animated_qr/show_animated_qr_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeferredPsbtQrEncoder implements PsbtQrEncoderPort {
  var completer = Completer<Result<List<String>, PsbtFlowFailure>>();

  @override
  Future<Result<List<String>, PsbtFlowFailure>> encode({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) => completer.future;
}

void main() {
  testWidgets('cycles QR parts and recovers from an encoding failure', (
    tester,
  ) async {
    final encoder = _DeferredPsbtQrEncoder();
    final cubit = ShowAnimatedQrCubit(
      generatePsbtQrPartsUsecase: GeneratePsbtQrPartsUsecase(encoder: encoder),
      psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
      qrType: QrType.urqr,
    );
    encoder.completer.complete(const Ok(['part-1', 'part-2']));
    await tester.pump();
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.parts, ['part-1', 'part-2']);
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.currentIndex, 1);

    encoder.completer = Completer();
    cubit.updateFragmentLength(150);
    encoder.completer.complete(const Err(PsbtFlowQrEncodingFailure()));
    await tester.pump();
    expect(cubit.state.failure, isA<PsbtFlowQrEncodingFailure>());
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.currentIndex, 1);

    encoder.completer = Completer();
    cubit.updateFragmentLength(200);
    expect(cubit.state.failure, isNull);
    encoder.completer.complete(const Ok(['retry-1', 'retry-2']));
    await tester.pump();
    expect(cubit.state.currentIndex, 0);
    expect(cubit.state.parts, ['retry-1', 'retry-2']);
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.currentIndex, 1);
    await cubit.close();
    await tester.pump(const Duration(seconds: 1));
    expect(cubit.state.currentIndex, 1);
  });

  test('does not emit after closing during UR generation', () async {
    final encoder = _DeferredPsbtQrEncoder();
    final cubit = ShowAnimatedQrCubit(
      generatePsbtQrPartsUsecase: GeneratePsbtQrPartsUsecase(encoder: encoder),
      psbt: 'cHNidP8BAAoAAAAAAAAAAAAA',
      qrType: QrType.urqr,
    );

    await cubit.close();
    encoder.completer.complete(const Ok(['part-1']));
    await Future<void>.delayed(Duration.zero);
  });
}
