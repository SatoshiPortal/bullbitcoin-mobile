import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../features/limit_orders/limit_order_fixtures.dart'
    show userSummary, limitOrderRate;

class _Summary extends Mock implements GetExchangeUserSummaryUsecase {}

class _Api extends Mock implements BullbitcoinApiDatasource {}

class _Settings extends Fake implements SettingsRepository {
  @override
  Future<SettingsEntity> fetch() async => const SettingsEntity(
    environment: Environment.testnet,
    bitcoinUnit: BitcoinUnit.btc,
    currencyCode: 'CAD',
  );
}

class _Logger extends Mock implements Logger {}

class _GetWallets extends Mock implements GetWalletsUsecase {}

class _Defaults extends Mock implements DefaultWalletsFacade {}

class _Rates extends Mock implements LimitOrderRepository {}

class _ReadDefaults extends Mock implements GetDefaultWalletsUsecase {}

class _SaveDefaults extends Mock implements SaveDefaultWalletUsecase {}

class _DeleteDefaults extends Mock implements DeleteDefaultWalletUsecase {}

void main() {
  late _Logger logger;
  late Logger previous;
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(WalletAddressType.bitcoin);
  });
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

  for (final refusal in [
    const ExchangeAuthenticationException(),
    const ExchangeAuthenticationException(ExchangeApiKeyReadFailure()),
    Exception('unexpected server reply'),
    StateError('programmer bug'),
  ]) {
    for (final name in [
      'limit orders',
      'autobuy status',
      'autobuy update',
      'account',
      'preferences',
      'upload status',
    ]) {
      test('$name classifies ${refusal.runtimeType}: $refusal', () async {
        final api = _Api();
        when(api.getUserSummary).thenThrow(refusal);
        final repo = ExchangeUserRepositoryImpl(bullbitcoinApiDatasource: api);
        final summary = GetExchangeUserSummaryUsecase(
          mainnetExchangeUserRepository: repo,
          testnetExchangeUserRepository: repo,
          settingsRepository: _Settings(),
        );
        final defaults = _Defaults();
        final wallets = _GetWallets();
        when(
          defaults.getDefaultWallets,
        ).thenAnswer((_) async => const DefaultWallets());
        when(wallets.execute).thenAnswer((_) async => const Ok([]));
        final pending = switch (name) {
          'limit orders' => LoadLimitOrderCreationUsecase(
            summary,
            defaults,
            wallets,
            _Rates(),
          ).execute(),
          'autobuy status' => GetAutoBuyStatusUsecase(summary).execute(),
          'autobuy update' => SetAutoBuyUsecase(
            summary,
            _ReadDefaults(),
            _Settings(),
            repo,
            repo,
          ).execute(enabled: false),
          'account' => GetAccountInfoUsecase(
            getExchangeUserSummaryUsecase: summary,
          ).execute(),
          'preferences' => GetExchangePreferencesUsecase(
            getExchangeUserSummaryUsecase: summary,
          ).execute(),
          _ => GetSecureFileUploadStatusUsecase(
            getExchangeUserSummaryUsecase: summary,
          ).execute(),
        };
        if (refusal is Error) {
          await expectLater(pending, throwsStateError);
          noReport();
        } else {
          expect(await pending, isA<Err>());
          if (refusal is ExchangeAuthenticationException) {
            noReport();
          } else {
            verify(
              () => logger.severe(
                message: any(named: 'message'),
                error: any(named: 'error'),
                trace: any(named: 'trace'),
              ),
            ).called(1);
          }
        }
      });
    }
  }

  for (final refusal in [
    ApiKeyNotFoundException(),
    const ExchangeCredentialUnavailableException(),
    Exception('unexpected reply'),
    StateError('programmer bug'),
  ]) {
    final expected =
        refusal is ApiKeyException ||
        refusal is ExchangeCredentialUnavailableException;
    for (final action in ['load', 'save', 'delete']) {
      test(
        'default wallets $action classifies ${refusal.runtimeType}',
        () async {
          final read = _ReadDefaults();
          final save = _SaveDefaults();
          final delete = _DeleteDefaults();
          when(read.execute).thenAnswer(
            (_) async => const DefaultWallets(
              bitcoin: DefaultWallet(
                recipientId: 'recipient',
                walletType: WalletAddressType.bitcoin,
                address: 'bc1qfixture',
              ),
            ),
          );
          when(
            () => save.execute(
              walletType: any(named: 'walletType'),
              address: any(named: 'address'),
              existingRecipientId: any(named: 'existingRecipientId'),
            ),
          ).thenThrow(refusal);
          when(
            () => delete.execute(
              walletType: any(named: 'walletType'),
              address: any(named: 'address'),
              recipientId: any(named: 'recipientId'),
            ),
          ).thenThrow(refusal);
          final cubit = DefaultWalletsCubit(
            getDefaultWalletsUsecase: read,
            saveDefaultWalletUsecase: save,
            deleteDefaultWalletUsecase: delete,
          );
          addTearDown(cubit.close);
          final Future<void> pending;
          if (action == 'load') {
            when(read.execute).thenThrow(refusal);
            pending = cubit.loadDefaultWallets();
          } else {
            await cubit.loadDefaultWallets();
            pending = action == 'save'
                ? cubit.saveWallet(WalletAddressType.bitcoin)
                : cubit.deleteWallet(WalletAddressType.bitcoin);
          }
          if (refusal is Error) {
            await expectLater(pending, throwsStateError);
          } else {
            await pending;
            expect(
              action == 'load' ? cubit.state.loadError : cubit.state.saveError,
              isNotNull,
            );
          }
          if (action == 'load') {
            verify(read.execute).called(1);
          } else if (action == 'save') {
            verify(
              () => save.execute(
                walletType: WalletAddressType.bitcoin,
                address: 'bc1qfixture',
                existingRecipientId: 'recipient',
              ),
            ).called(1);
          } else {
            verify(
              () => delete.execute(
                walletType: WalletAddressType.bitcoin,
                address: 'bc1qfixture',
                recipientId: 'recipient',
              ),
            ).called(1);
          }
          if (expected || refusal is Error) {
            noReport();
          } else {
            verify(
              () => logger.severe(
                message: any(named: 'message'),
                error: any(named: 'error'),
                trace: any(named: 'trace'),
              ),
            ).called(1);
          }
        },
      );
    }
    for (final name in ['limit orders', 'autobuy']) {
      test('$name classifies default-wallet ${refusal.runtimeType}', () async {
        final summary = _Summary();
        when(summary.execute).thenAnswer((_) async => userSummary());
        final defaults = _Defaults();
        final wallets = _GetWallets();
        final read = _ReadDefaults();
        final rates = _Rates();
        when(
          () => rates.getRate(any()),
        ).thenAnswer((_) async => Ok(limitOrderRate()));
        when(defaults.getDefaultWallets).thenThrow(refusal);
        when(read.execute).thenThrow(refusal);
        when(wallets.execute).thenAnswer((_) async => const Ok([]));
        final repo = ExchangeUserRepositoryImpl(
          bullbitcoinApiDatasource: _Api(),
        );
        final pending = name == 'limit orders'
            ? LoadLimitOrderCreationUsecase(
                summary,
                defaults,
                wallets,
                rates,
              ).execute()
            : SetAutoBuyUsecase(
                summary,
                read,
                _Settings(),
                repo,
                repo,
              ).execute(enabled: true);
        if (refusal is Error) {
          await expectLater(pending, throwsStateError);
        } else {
          expect(await pending, isA<Err>());
        }
        if (name == 'limit orders') {
          verify(defaults.getDefaultWallets).called(1);
          verifyNever(() => rates.getRate(any()));
        } else {
          verify(read.execute).called(1);
        }
        if (expected || refusal is Error) {
          noReport();
        } else {
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
}
