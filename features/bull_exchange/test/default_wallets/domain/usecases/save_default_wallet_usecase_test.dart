import 'dart:async';

import 'package:bull_exchange/src/default_wallets/domain/usecases/save_default_wallet_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'default_wallets_usecase_test_support.dart';

import 'package:primitives/primitives.dart';

const _wallet = DefaultWallet(
  recipientId: 'r-1',
  walletType: BtcNetwork.liquid,
  address: 'lq1new',
);

Exchange _exchange(
  List<String> sent,
  Future<Result<DefaultWallet, ExchangeWriteFailure>> Function() answer,
) => exchangeForTesting(
  access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
  saveDefaultWallet:
      ({required walletType, required address, existingRecipientId}) {
        sent.add('${walletType.name} $address $existingRecipientId');
        return answer();
      },
);

void main() {
  test('saves the network, address and recipient it was given', () async {
    final sent = <String>[];
    final write =
        await SaveDefaultWalletUsecase(
          _exchange(sent, () async => const Ok(_wallet)),
        ).execute(
          dwSession,
          network: BtcNetwork.liquid,
          address: 'lq1new',
          existingRecipientId: 'r-1',
        );
    expect(sent, ['liquid lq1new r-1']);
    expect(write, isA<Ok<DefaultWallet, ExchangeGatedWriteFailure>>());
  });

  test('an unknown outcome stays unknown', () async {
    final write = await SaveDefaultWalletUsecase(
      _exchange(
        [],
        () async => const Err(ExchangeWriteOutcomeUnknownFailure('timeout')),
      ),
    ).execute(dwSession, network: BtcNetwork.bitcoin, address: 'bc1q');
    expect(
      write,
      isA<Err<DefaultWallet, ExchangeGatedWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteOutcomeUnknownFailure>(),
      ),
    );
  });

  test('a save for another session is never sent', () async {
    final sent = <String>[];
    final write = await SaveDefaultWalletUsecase(
      _exchange(sent, () async => const Ok(_wallet)),
    ).execute(dwOtherSession, network: BtcNetwork.bitcoin, address: 'bc1q');
    expect(sent, isEmpty);
    expect(
      write,
      isA<Err<DefaultWallet, ExchangeGatedWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteNotSentFailure>().having(
          (w) => w.reason,
          'reason',
          ExchangeNotSentReason.sessionChanged,
        ),
      ),
    );
  });

  test('a second save while one runs is refused by the gate', () async {
    final sent = <String>[];
    final release = Completer<Result<DefaultWallet, ExchangeWriteFailure>>();
    final usecase = SaveDefaultWalletUsecase(
      _exchange(sent, () => release.future),
    );
    final first = usecase.execute(
      dwSession,
      network: BtcNetwork.bitcoin,
      address: 'bc1qa',
    );
    final second = await usecase.execute(
      dwSession,
      network: BtcNetwork.bitcoin,
      address: 'bc1qb',
    );
    expect(
      second,
      isA<Err<DefaultWallet, ExchangeGatedWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteBusyFailure>(),
      ),
    );
    release.complete(const Ok(_wallet));
    await first;
    expect(sent, ['bitcoin bc1qa null']);
  });
}
