import 'package:ark/ark.dart';
import 'package:bb_mobile/features/send/legacy_send_flow.dart';
import 'package:bb_mobile/features/send/presentation/send_ark_cubit.dart';
import 'package:bull_ark/bull_ark.dart' show ArkAccountsFacade;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';
import 'package:send/send.dart' show SendArkRouteUnavailableFailure;

/// Classifier-only regtest HRP/checksum fixture; not native payment validity.
const address =
    'tark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mq47jn9z';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );

  late GetIt locator;

  setUp(() => locator = GetIt.asNewInstance());

  tearDown(() => locator.reset());

  Future<SendArkCubit> pasteArkAddress() async {
    final cubit = locator<SendArkCubit>();
    addTearDown(cubit.close);
    await cubit.resolve(
      input: address,
      network: BitcoinNetwork.regtest,
      coinControl: false,
      sweep: false,
      silentPayments: false,
      multipleRecipients: false,
    );
    return cubit;
  }

  test('a mounted Ark host routes a pasted Ark address to send', () async {
    // Exactly what ArkForegroundHost.setup registers: the host-backed
    // enabled-accounts capability, resolved lazily per request.
    locator.registerSingleton<ArkAccountsFacade>(
      ArkAccountsFacade((network) async => Ok([account])),
    );
    LegacySendFlow.mount(locator);

    final cubit = await pasteArkAddress();

    expect(
      cubit.state,
      isA<SendArkReady>().having(
        (state) => state.request.accounts,
        'enabled accounts',
        [account],
      ),
    );
  });

  test('without a mounted Ark host a pasted Ark address stays unavailable', () async {
    LegacySendFlow.mount(locator);

    final cubit = await pasteArkAddress();

    expect(
      cubit.state,
      isA<SendArkUnavailable>().having(
        (state) => state.failure,
        'reason',
        isA<SendArkRouteUnavailableFailure>(),
      ),
    );
  });
}
