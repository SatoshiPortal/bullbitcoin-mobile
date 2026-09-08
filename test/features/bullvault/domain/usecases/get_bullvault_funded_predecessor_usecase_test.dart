import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_funded_predecessor_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';

class _MockRepository extends Mock implements BullVaultRepository {}

class _MockGetWallet extends Mock implements GetWalletUsecase {}

void main() {
  test(
    'finds late deposits in predecessors and cancelled replacements',
    () async {
      final repository = _MockRepository();
      final getWallet = _MockGetWallet();
      final active = testBullVaultCreateResult().wallet;
      final balances = <String, Wallet>{
        'previous': active.copyWith(balanceSat: BigInt.zero),
        'cancelled': active.copyWith(balanceSat: BigInt.zero),
      };
      when(() => repository.getMigrationDestinations({active.id})).thenAnswer(
        (_) async => Ok({
          'missing': active.id,
          'previous': active.id,
          'cancelled': active.id,
        }),
      );
      when(
        () => getWallet.execute(any()),
      ).thenAnswer((call) async => balances[call.positionalArguments.single]);
      final usecase = GetBullVaultFundedPredecessorUsecase(
        repository,
        getWallet,
      );
      Future<String?> destination() async =>
          (await usecase.execute([active]) as Ok<String?, BullVaultFailure>)
              .value;

      expect(await destination(), isNull);
      for (final source in ['previous', 'cancelled']) {
        balances[source] = balances[source]!.copyWith(
          balanceSat: BigInt.from(1000),
        );
        expect(await destination(), active.id);
        balances[source] = balances[source]!.copyWith(balanceSat: BigInt.zero);
        expect(await destination(), isNull);
      }
    },
  );
}
