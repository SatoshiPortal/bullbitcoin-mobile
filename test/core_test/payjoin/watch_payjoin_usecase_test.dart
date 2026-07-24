import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

Payjoin _receiver(String id) => Payjoin.receiver(
  id: id,
  isTestnet: true,
  walletId: 'w1',
  pjUri: 'bitcoin:tb1q?pj=https://payjo.in',
  createdAt: DateTime(2020),
  expiresAt: DateTime(2020, 1, 1, 0, 5),
);

Payjoin _sender(String uri, {PayjoinStatus status = PayjoinStatus.proposed}) =>
    Payjoin.sender(
      status: status,
      uri: uri,
      isTestnet: true,
      walletId: 'w1',
      originalPsbt: 'cHNidP8=',
      originalTxId: 'orig-txid',
      amountSat: 50000,
      createdAt: DateTime(2020),
      expiresAt: DateTime(2020, 1, 1, 0, 5),
    );

void main() {
  late _MockPayjoinRepository repository;
  late WatchPayjoinUsecase usecase;

  setUp(() {
    repository = _MockPayjoinRepository();
    usecase = WatchPayjoinUsecase(payjoinRepository: repository);
  });

  test('emits both receiver and sender payjoins (senders are not filtered '
      'out — #2246)', () async {
    final receiver = _receiver('r1');
    final sender = _sender('s1');
    when(
      () => repository.payjoinStream,
    ).thenAnswer((_) => Stream.fromIterable([receiver, sender]));

    final emitted = await usecase.execute().toList();

    // The send flow depends on sender events reaching it; a receiver-only
    // filter here would swallow them and hang the "coordinating" screen.
    expect(emitted, [receiver, sender]);
  });

  test('scopes emissions to the requested ids', () async {
    final wanted = _sender('wanted');
    final other = _sender('other');
    when(
      () => repository.payjoinStream,
    ).thenAnswer((_) => Stream.fromIterable([wanted, other]));

    final emitted = await usecase.execute(ids: ['wanted']).toList();

    expect(emitted, [wanted]);
  });
}
