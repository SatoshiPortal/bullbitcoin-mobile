import 'dart:async';

import 'package:bull_exchange/src/dca/presentation/dca_flow.dart';
import 'package:bull_exchange/src/dca/presentation/dca_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dca_fixtures.dart';

final class _Calls {
  final log = <String>[];
  Completer<GatedWrite<ExchangeWrite<DcaPlan>>> answer = Completer();
  ExchangeRead<UserSummary> reread = ReadGot(buySummaryWith());

  DcaFlowCalls of(ExchangeSession session) => (
    loadContext: () async {
      log.add('load');
      return ReadGot(dcaContext);
    },
    rate: (market) async {
      log.add('rate ${market.currency.code}');
      return const ReadGot(50000.0);
    },
    defaultWallets: () async {
      log.add('wallets');
      return const ReadGot(DefaultWallets());
    },
    create: (effect) async {
      log.add('create ${effect.attempt}');
      return ConfirmAnswered(effect.attempt, await answer.future);
    },
    readSummary: () async {
      log.add('summary');
      return reread;
    },
    activate: () async => log.add('activate'),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Calls calls;
  late StreamController<ExchangeAccess> access;
  late DcaFlowBloc bloc;

  setUp(() {
    calls = _Calls();
    access = StreamController<ExchangeAccess>.broadcast();
    bloc = DcaFlowBloc(
      calls: calls.of,
      session: buySession,
      accessChanges: access.stream,
    );
  });

  tearDown(() async {
    await bloc.close();
    await access.close();
  });

  Future<void> send(List<DcaFlowEvent> events) async {
    for (final event in events) {
      bloc.add(event);
      await _settle();
    }
  }

  Future<void> toReview() async {
    await _settle();
    await send(const [
      DcaAmountChanged(AmountTyped('10')),
      DcaFrequencyPicked(DcaBuyFrequency.weekly),
      DcaContinuePressed(),
      DcaPayoutChosen(dcaPayout),
    ]);
  }

  test('loads, then creates once and turns the preference on', () async {
    await toReview();
    expect(calls.log, ['load', 'rate CAD']);
    expect(bloc.state, isA<DcaReview>());
    await send(const [DcaConfirmPressed(), DcaConfirmPressed()]);
    expect(calls.log.where((l) => l.startsWith('create')), ['create 1']);
    calls.answer.complete(
      GateAdmitted(WriteDone((bloc.state as DcaConfirming).plan)),
    );
    await _settle();
    expect(bloc.state, isA<DcaDone>());
    expect(calls.log.last, 'activate');
  });

  test('an unknown create re-reads the account', () async {
    await toReview();
    await send(const [DcaConfirmPressed()]);
    calls.reread = ReadGot(
      buySummaryWith().copyWith(
        dca: const UserDca(isActive: true, address: 'bc1qdefault'),
      ),
    );
    calls.answer.complete(const GateAdmitted(WriteOutcomeUnknown('lost')));
    await _settle();
    expect(calls.log, contains('summary'));
    expect(bloc.state, isA<DcaDone>());
    expect(calls.log.where((l) => l.startsWith('create')), ['create 1']);
  });

  test('back from the editor re-reads the default wallets', () async {
    await _settle();
    await send(const [
      DcaAmountChanged(AmountTyped('10')),
      DcaFrequencyPicked(DcaBuyFrequency.weekly),
      DcaContinuePressed(),
      DcaDefaultWalletsReturned(),
    ]);
    expect(calls.log.last, 'wallets');
  });

  test('a session change ends the flow', () async {
    await _settle();
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(bloc.state, isA<DcaSessionEnded>());
  });
}
