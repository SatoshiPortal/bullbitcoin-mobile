import 'package:bb_mobile/core/blockchain/domain/usecases/get_bitcoin_chain_tip_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetBitcoinChainTipUsecase extends Mock
    implements GetBitcoinChainTipUsecase {}

void main() {
  late _MockGetBitcoinChainTipUsecase getChainTip;
  final now = DateTime.utc(2027, 1, 15, 12);

  setUp(() {
    getChainTip = _MockGetBitcoinChainTipUsecase();
  });

  test('uses phone UTC after checking it against chain time', () async {
    when(() => getChainTip.execute(isTestnet: false)).thenAnswer(
      (_) async => (
        height: 900_000,
        medianTimePast:
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      ),
    );
    final usecase = PrepareBullVaultTimeReferenceUsecase(
      getChainTip,
      clock: () => now,
    );

    final result = await usecase.execute(isTestnet: false);

    final reference =
        (result as Ok<BullVaultTimeReference, BullVaultFailure>).value;
    expect(reference.deviceTime, now);
    expect(reference.chainHeight, 900_000);
  });

  test('rejects a chain time more than 24 hours from phone UTC', () async {
    when(() => getChainTip.execute(isTestnet: false)).thenAnswer(
      (_) async => (
        height: 900_000,
        medianTimePast:
            now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch ~/
            1000,
      ),
    );
    final usecase = PrepareBullVaultTimeReferenceUsecase(
      getChainTip,
      clock: () => now,
    );

    final result = await usecase.execute(isTestnet: false);

    expect(
      (result as Err<BullVaultTimeReference, BullVaultFailure>).failure,
      isA<BullVaultClockMismatchFailure>(),
    );
  });
}
