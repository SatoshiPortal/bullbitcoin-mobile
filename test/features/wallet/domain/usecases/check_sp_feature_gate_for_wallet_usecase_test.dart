import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSpFacade extends Mock implements Silent {}

void main() {
  group('CheckSpFeatureGateForWalletUsecase', () {
    late _MockSpFacade facade;
    late CheckSpFeatureGateForWalletUsecase usecase;

    setUp(() {
      facade = _MockSpFacade();
      usecase = CheckSpFeatureGateForWalletUsecase(silent: facade);
    });

    test('forwards the facade gate result', () async {
      when(() => facade.isFeatureEnabled())
          .thenAnswer((_) async => const Ok(true));
      expect(
        (await usecase.execute()).fold((value) => value, (_) => null),
        isTrue,
      );
      verify(() => facade.isFeatureEnabled()).called(1);
    });

    test('forwards a disabled gate', () async {
      when(() => facade.isFeatureEnabled())
          .thenAnswer((_) async => const Ok(false));
      expect(
        (await usecase.execute()).fold((value) => value, (_) => null),
        isFalse,
      );
    });
  });
}
