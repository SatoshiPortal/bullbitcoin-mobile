import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSpFacade extends Mock implements SpFacade {}

void main() {
  group('CheckSpFeatureGateForWalletUsecase', () {
    late _MockSpFacade facade;
    late CheckSpFeatureGateForWalletUsecase usecase;

    setUp(() {
      facade = _MockSpFacade();
      usecase = CheckSpFeatureGateForWalletUsecase(spFacade: facade);
    });

    test('forwards the facade gate result', () async {
      when(() => facade.isFeatureEnabled()).thenAnswer((_) async => true);
      expect(await usecase.execute(), isTrue);
      verify(() => facade.isFeatureEnabled()).called(1);
    });

    test('forwards a disabled gate', () async {
      when(() => facade.isFeatureEnabled()).thenAnswer((_) async => false);
      expect(await usecase.execute(), isFalse);
    });
  });
}
