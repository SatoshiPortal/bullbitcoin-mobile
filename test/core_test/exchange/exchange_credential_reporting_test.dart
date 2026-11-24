import 'dart:typed_data';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:address_view/payment_destination.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/testing.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/write.dart';
import 'package:bbx_api/bbx_api_testing.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/exchange/data/bbx_api_test_http.dart';

/// Throws [error] for every request, as a failing transport.
class _Throwing implements HttpClientAdapter {
  final Object error;

  _Throwing(this.error);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw error;

  @override
  void close({bool force = false}) {}
}

/// A refusal of the user summary call.
sealed class _Refusal {
  const _Refusal();
}

/// The credential read found no key: the user is signed out.
final class _MissingKey extends _Refusal {
  const _MissingKey();
}

/// The credential read failed: the key is stored but unreadable.
final class _UnreadableKey extends _Refusal {
  const _UnreadableKey();
}

/// The transport threw [error].
final class _Thrown extends _Refusal {
  final Object error;

  const _Thrown(this.error);

  bool get isProgrammerError => error is Error;
}

Exchange _users(_Refusal refusal) => exchangeWithTransportForTesting(
  readSession: () async => switch (refusal) {
    _UnreadableKey() => const Err(ExchangeCredentialReadFailure()),
    _ => Ok((
      environment: ExchangeEnvironment.testnet,
      epoch: 0,
      apiKey: refusal is _MissingKey ? null : anonymousTestApiKey,
    )),
  },
  openClient: (endpoint, readKey) => bbxForTesting(
    endpoint: endpoint.toString(),
    adapter: _Throwing(switch (refusal) {
      _Thrown(:final error) => error,
      // Never reached: a credential refusal stops the request first.
      _ => StateError('no request expected'),
    }),
    readActiveApiKey: readKey,
  ),
);

class _Settings extends Fake implements Preferences {
  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async => const Ok(Environment.testnet);

  @override
  Future<Result<SettingsEntity, PreferencesFailure>> fetch() async => Ok(
    const SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'CAD',
    ),
  );
}

class _Logger extends Mock implements Logger {}

class _Inventory extends Mock implements WalletInventory {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _Rates extends Mock implements ExchangeLimitOrders {}

/// The Bitcoin destination check the default-wallet editor uses.
Future<String?> _validateBitcoin(BtcNetwork _, String raw) async =>
    (await const PaymentDestinations().validate(
      raw,
      acceptedTypes: const {PaymentDestinationType.bitcoin},
    ))?.address;

void main() {
  late _Logger logger;
  late Logger previous;
  setUpAll(() async {
    await BullSdk.init();
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(BtcNetwork.bitcoin);
  });
  tearDownAll(BullSdk.dispose);
  setUp(() {
    previous = log;
    logger = _Logger();
    log = logger;
  });
  tearDown(() => log = previous);
  void noReport() => verifyNever(
    () => logger.severe(
      message: any(named: 'message'),
      error: any(named: 'error'),
      trace: any(named: 'trace'),
    ),
  );

  for (final (label, refusal) in <(String, _Refusal)>[
    ('a missing key', const _MissingKey()),
    ('an unreadable key', const _UnreadableKey()),
    ('a foreign exception', _Thrown(Exception('unexpected server reply'))),
    ('a programmer error', _Thrown(StateError('programmer bug'))),
  ]) {
    for (final name in ['limit orders', 'autobuy status', 'autobuy update']) {
      test('$name classifies $label', () async {
        final repo = _users(refusal);
        final wallets = _Inventory();
        for (final network in <Network>[
          BitcoinNetwork.testnet,
          LiquidNetwork.testnet,
        ]) {
          when(() => wallets.walletsForNetwork(network))
              .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
        }
        final pending = switch (name) {
          'limit orders' => LoadLimitOrderCreationUsecase(
            exchangeForTesting(
              getDefaultWallets: () async => const Ok(DefaultWallets()),
              getUserSummary: repo.getUserSummary,
            ),
            _Settings(),
            ExchangePayoutWallets(wallets, _Native()),
            _Rates(),
          ).execute(),
          'autobuy status' => autoBuyStatusForTesting(repo),
          'autobuy update' => disableAutoBuyForTesting(repo, _Settings()),
          _ => fail('Unexpected use case name'),
        };
        if (refusal is _Thrown && refusal.isProgrammerError) {
          await expectLater(pending, throwsStateError);
          noReport();
        } else if (refusal is _MissingKey || refusal is _UnreadableKey) {
          expect(await pending, isA<Err>());
          noReport();
        } else if (name == 'limit orders') {
          expect(await pending, isA<Err>());
          verify(
            () => logger.severe(
              message:
                  'Failed to load the account before creating a limit order',
              error: ExchangeAccountUnavailableFailure,
              trace: any(named: 'trace'),
            ),
          ).called(1);
        } else {
          expect(await pending, isA<Err>());
          verify(
            () => logger.severe(
              message: any(named: 'message'),
              error: any(named: 'error'),
              trace: any(named: 'trace'),
            ),
          ).called(1);
        }
      });
    }
  }

  const session = ExchangeSession(
    environment: ExchangeEnvironment.testnet,
    epoch: 1,
    sessionId: 's',
  );

  for (final failure in const [
    ExchangeNotAuthenticatedFailure(),
    ExchangeCredentialReadFailure(),
    ExchangeUnexpectedFailure(),
  ]) {
    test(
      'default wallet operations answer a closed result and do not report ${failure.runtimeType}',
      () async {
        const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
        final exchange = exchangeForTesting(
          access: fixedAccessForTesting(const ExchangeAccessSignedIn(session)),
          getDefaultWallets: () async => Err(failure),
          saveDefaultWallet: ({
            required walletType,
            required address,
            existingRecipientId,
          }) async => const WriteNotSent(ExchangeNotSentReason.signedOut),
          deleteDefaultWallet: ({
            required recipientId,
            required walletType,
            required address,
          }) async => const WriteNotSent(ExchangeNotSentReason.signedOut),
        );
        Future<DefaultWalletsEvent> run(DefaultWalletsEffect effect) =>
            defaultWalletsEffectForTesting(
              effect,
              exchange: exchange,
              validate: _validateBitcoin,
            );

        expect(
          await run(const FetchDefaultWallets(session, 1)),
          isA<WalletsLoaded>().having(
            (e) => e.read,
            'read',
            isNot(isA<ReadGot<DefaultWallets>>()),
          ),
        );
        expect(
          await run(
            const SaveDefaultWallet(session, BtcNetwork.bitcoin, 2, address),
          ),
          isA<SlotSaveAnswered>(),
        );
        expect(
          await run(
            const UnsetDefaultWallet(
              session,
              BtcNetwork.bitcoin,
              3,
              recipientId: 'recipient',
              address: address,
            ),
          ),
          isA<SlotUnsetAnswered>(),
        );
        noReport();
      },
    );
  }

  test(
    'default wallet loading does not report or swallow programmer errors',
    () async {
      await expectLater(
        defaultWalletsEffectForTesting(
          const FetchDefaultWallets(session, 1),
          exchange: exchangeForTesting(
            access: fixedAccessForTesting(
              const ExchangeAccessSignedIn(session),
            ),
            getDefaultWallets: () =>
                throw StateError('synthetic programming error'),
          ),
          validate: _validateBitcoin,
        ),
        throwsStateError,
      );
      noReport();
    },
  );
}
