import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';

import 'dart:io';

import 'package:fees/fees.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/send/data/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' show SyncStorageFailure;

class _Metadata extends Mock implements WalletRegistrations {}

class _Frozen extends Mock implements SyncFreezesDatasource {}

class _Sdk extends Mock implements BullSdkApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const walletId = 'elwpkh([73c5da0a/84h/1h/0h])';
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late LiquidWalletRepository repository;
  final sdk = _Sdk();

  setUpAll(() {
    BullSdk.initMock(api: sdk);
  });

  setUp(() {
    final metadata = _Metadata();
    final frozen = _Frozen();
    reset(sdk);
    when(() => sdk.lwkApiTypesAddressValidate(addressString: 'recipient'))
        .thenAnswer((_) async => lwk.LiquidNetwork.testnet);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => Directory.systemTemp.path,
        );
    when(() => metadata.fetch(walletId)).thenAnswer(
      (_) async => const WalletMetadataModel(
        id: walletId,
        networkCode: 'liquidTestnet',
        masterFingerprint: '73c5da0a',
        xpubFingerprint: 'deadbeef',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: '',
        externalPublicDescriptor: 'descriptor',
        internalPublicDescriptor: '',
        signer: Signer.local,
        isDefault: false,
      ),
    );
    when(() => frozen.getFrozenOutpoints()).thenAnswer((_) async => {});
    repository = LiquidWalletRepository(
      walletRegistrations: metadata,
      secrets: Secrets(scratchDirectory: () async => Directory.systemTemp.path),
      // The native wallet cannot be opened.
      wallet: (_) async => const Err(SyncStorageFailure()),
      // No coin is read: nothing is frozen and no input is selected.
      walletValuesDatasource: SyncWalletValuesDatasource(
        load: (_) async => throw StateError('no value read expected'),
      ),
      freezesDatasource: frozen,
    );
  });

  tearDownAll(BullSdk.dispose);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns a Pay failure when the native wallet cannot open', () async {
    final usecase = PreparePayLiquidPayinUsecase(
      liquidWalletRepository: repository,
    );
    await expectLater(
      usecase.execute(
        walletId: walletId,
        address: 'recipient',
        amountSat: 1000,
        feeRate: const RelativeFee(25),
      ),
      completion(isA<Err<String, PayFailure>>()),
    );
  });
}
