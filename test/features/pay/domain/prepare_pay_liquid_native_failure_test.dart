import 'dart:io';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/prepare_pay_liquid_payin_usecase.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Frozen extends Mock implements FrozenWalletUtxoDatasource {}

class _Sdk extends Mock implements BullSdkApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const walletId = 'elwpkh([73c5da0a/84h/1h/0h])';
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const nativeFailure = lwk.LwkError(msg: 'cache read failed');
  late LiquidWalletRepository repository;
  final sdk = _Sdk();

  setUpAll(() {
    registerFallbackValue(const lwk.Descriptor(ctDescriptor: 'descriptor'));
    BullSdk.initMock(api: sdk);
  });

  setUp(() {
    final metadata = _Metadata();
    final frozen = _Frozen();
    reset(sdk);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => Directory.systemTemp.path,
        );
    when(() => metadata.fetch(walletId)).thenAnswer(
      (_) async => const WalletMetadataModel(
        id: walletId,
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
    when(() => frozen.getAllFrozen()).thenAnswer((_) async => []);
    // Only the native call is substituted: the real LwkFacade and real
    // LwkWalletDatasource must propagate its failure through the repository.
    when(
      () => sdk.lwkApiWalletWalletInit(
        network: lwk.LiquidNetwork.testnet,
        dbpath: any(named: 'dbpath'),
        descriptor: any(named: 'descriptor'),
      ),
    ).thenAnswer((_) async => throw nativeFailure);
    repository = LiquidWalletRepository(
      walletMetadataDatasource: metadata,
      secrets: Secrets(scratchDirectory: () async => Directory.systemTemp.path),
      lwkWalletDatasource: LwkWalletDatasource(),
      frozenWalletUtxoDatasource: frozen,
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
