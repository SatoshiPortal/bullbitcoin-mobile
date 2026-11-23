import 'dart:typed_data';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/ui/default_wallets_payout_binding.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
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
  Future<Result<SettingsEntity, PreferencesFailure>> fetch() async => Ok(
    const SettingsEntity(
      environment: Environment.testnet,
      bitcoinUnit: BitcoinUnit.btc,
      currencyCode: 'CAD',
    ),
  );
}

class _Logger extends Mock implements Logger {}

class _GetWallets extends Mock implements GetWalletsUsecase {}

class _Rates extends Mock implements ExchangeLimitOrders {}

void main() {
  late _Logger logger;
  late Logger previous;
  setUpAll(() async {
    await BullSdk.init();
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(WalletAddressType.bitcoin);
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
        final summary = GetExchangeUserSummaryUsecase(
          exchange: repo,
          settingsRepository: _Settings(),
        );
        final wallets = _GetWallets();
        when(wallets.execute).thenAnswer((_) async => const Ok([]));
        final pending = switch (name) {
          'limit orders' => LoadLimitOrderCreationUsecase(
            summary,
            exchangeForTesting(
              getDefaultWallets: () async => const Ok(DefaultWallets()),
            ),
            wallets,
            _Rates(),
          ).execute(),
          'autobuy status' => GetAutoBuyStatusUsecase(summary).execute(),
          'autobuy update' => SetAutoBuyUsecase(
            summary,
            _Settings(),
            repo,
          ).execute(enabled: false),
          _ => fail('Unexpected use case name'),
        };
        if (refusal is _Thrown && refusal.isProgrammerError) {
          await expectLater(pending, throwsStateError);
          noReport();
        } else if (refusal is _MissingKey || refusal is _UnreadableKey) {
          expect(await pending, isA<Err>());
          noReport();
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

  for (final failure in const [
    ExchangeNotAuthenticatedFailure(),
    ExchangeCredentialReadFailure(),
    ExchangeUnexpectedFailure(),
  ]) {
    test(
      'default wallet operations retain state and do not report ${failure.runtimeType}',
      () async {
        const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
        var failLoad = false;
        final cubit = defaultWalletsCubitForTesting(
          validate: exchangePayoutFields.validate,
          exchange: exchangeForTesting(
            getDefaultWallets: () async => failLoad
                ? Err(failure)
                : const Ok(
                    DefaultWallets(
                      bitcoin: DefaultWallet(
                        recipientId: 'recipient',
                        walletType: WalletAddressType.bitcoin,
                        address: address,
                      ),
                    ),
                  ),
            saveDefaultWallet: ({
              required walletType,
              required address,
              existingRecipientId,
            }) async => Err(failure),
            deleteDefaultWallet: ({
              required recipientId,
              required walletType,
              required address,
            }) async => Err(failure),
          ),
        );
        addTearDown(cubit.close);
        await cubit.loadDefaultWallets();
        await cubit.saveWallet(WalletAddressType.bitcoin);
        expect(cubit.state.saveError, isNotNull);
        await cubit.deleteWallet(WalletAddressType.bitcoin);
        expect(cubit.state.saveError, isNotNull);
        failLoad = true;
        await cubit.loadDefaultWallets();
        expect(cubit.state.loadError, isNotNull);
        noReport();
      },
    );
  }

  test(
    'default wallet loading does not report or swallow programmer errors',
    () async {
      final cubit = defaultWalletsCubitForTesting(
        validate: exchangePayoutFields.validate,
        exchange: _users(_Thrown(StateError('synthetic programming error'))),
      );
      addTearDown(cubit.close);

      await expectLater(cubit.loadDefaultWallets(), throwsStateError);
      noReport();
    },
  );
}
