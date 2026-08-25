import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/widgets/animated_psbt_qr/show_animated_qr_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not emit after closing during UR generation', () async {
    final cubit = ShowAnimatedQrCubit(
      psbt: base64.encode(List<int>.filled(1000, 0)),
      qrType: QrType.urqr,
    );

    await cubit.close();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.isClosed, isTrue);
  });

  test(
    'uses a larger UR fragment before reporting a valid payload as large',
    () async {
      final cubit = ShowAnimatedQrCubit(
        psbt: base64.encode(List<int>.filled(100000, 0)),
        qrType: QrType.urqr,
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(cubit.state.isTooLarge, isFalse);
      expect(cubit.state.fragmentLength, 200);
      expect(cubit.state.parts, isNotEmpty);
    },
  );
}
