import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/usecases/parse_ark_destination_usecase.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_payment_cubit_test.dart' show PaymentRig;

// Synthetic syntax only. Native quote remains the checksum/network validator.
String syntax(String prefix) => '${prefix}q${'q' * 38}';

void main() {
  for (final network in BitcoinNetwork.values) {
    test(
      'classifies raw Bitcoin syntax only for $network without rewriting',
      () {
        final prefix = switch (network) {
          BitcoinNetwork.mainnet => 'bc1',
          BitcoinNetwork.testnet || BitcoinNetwork.signet => 'tb1',
          BitcoinNetwork.regtest => 'bcrt1',
        };
        for (final value in [syntax(prefix), syntax(prefix).toUpperCase()]) {
          final result = const ParseArkDestinationUsecase().execute(
            value,
            network: network,
          );
          expect(result, isA<Ok<ArkPaymentDestination, ArkFailure>>());
          if (result case Ok(:final value)) {
            expect(value.kind, ArkDestinationKind.bitcoin);
          }
          if (result case Ok(value: final destination)) {
            expect(destination.value, value);
          }
        }
      },
    );
  }

  test(
    'rejects wrong network, mixed case and BIP21 instead of ignoring amounts',
    () {
      for (final value in [
        syntax('bc1'),
        syntax('tb1'),
        'bcrt1Q${'q' * 38}',
        'bitcoin:${syntax('bcrt1')}',
        'bitcoin:${syntax('bcrt1')}?amount=1',
        '${syntax('bcrt1')}#fragment',
        '${syntax('bcrt1')} extra',
        'bcrt1q${'q' * 90}',
        'bcrt1q${'q' * 20}K',
        'bcrt1q${'q' * 20}b',
      ]) {
        expect(
          const ParseArkDestinationUsecase().execute(
            value,
            network: BitcoinNetwork.regtest,
          ),
          isA<Err>(),
          reason: value,
        );
      }
    },
  );

  test('legacy prefixes retain case and the supported chain family', () {
    const parse = ParseArkDestinationUsecase();
    final mainnet = '1${'A' * 25}';
    final testnet = 'm${'A' * 25}';
    expect(parse.execute(mainnet, network: BitcoinNetwork.mainnet), isA<Ok>());
    expect(parse.execute(mainnet, network: BitcoinNetwork.regtest), isA<Err>());
    expect(parse.execute(testnet, network: BitcoinNetwork.regtest), isA<Ok>());
    expect(parse.execute(testnet, network: BitcoinNetwork.mainnet), isA<Err>());
  });

  test('Bitcoin Send reaches only the cooperative quote until explicit confirmation', () async {
    final rig = PaymentRig();
    final destination = syntax('bcrt1');
    rig.client.quoted = Ok(
      ArkQuote(
        id: 'public-bitcoin-quote',
        account: rig.cubit.account,
        generation: 1,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
        kind: ArkOperationKind.payment,
        destination: destination,
        destinationKind: ArkDestinationKind.bitcoin,
        amount: Sats.fromInt(1100),
        fee: Sats.fromInt(100),
        net: Sats.fromInt(1000),
        observedTip: 100,
        validUntil: DateTime.utc(2030),
      ),
    );
    await rig.cubit.review(destination: destination, amount: '1000');
    expect(rig.cubit.state, isA<ArkPaymentReview>());
    expect(rig.client.calls, ['quote']);
    if (rig.client.arguments.single case (
      final ArkAccountId owner,
      final ArkPaymentQuoteRequest request,
    )) {
      expect(owner, rig.cubit.account);
      expect(request.destination.kind, ArkDestinationKind.bitcoin);
      expect(request.destination.value, destination);
      expect(request.amount, Sats.fromInt(1000));
    } else {
      fail(
        'The explicit review must pass the typed cooperative payment request',
      );
    }
    expect(rig.ids, 0);
    rig.client.submitted = Ok(
      ArkOperation(
        id: 'payment-1',
        kind: ArkOperationKind.payment,
        status: ArkOperationStatus.pending,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      ),
    );
    await rig.cubit.confirm();
    expect(rig.client.calls, ['quote', 'submit']);
    expect(rig.ids, 1);
  });

  test(
    'native rejection of syntactic Bitcoin input never admits a payment',
    () async {
      final rig = PaymentRig();
      rig.client.quoted = const Err(
        ArkValidationFailure(ArkFailureReason.validation),
      );
      await rig.cubit.review(destination: syntax('bcrt1'), amount: '1000');
      expect(rig.client.calls, ['quote']);
      expect(rig.cubit.state, isA<ArkPaymentEditing>());
      await rig.cubit.confirm();
      expect(rig.ids, 0);
      expect(rig.client.journal, isEmpty);
      expect(rig.client.calls, ['quote']);
    },
  );
}
