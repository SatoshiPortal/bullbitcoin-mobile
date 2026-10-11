import 'dart:io';

import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart' hide ScriptType, Network;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import '../bdk_wallet_test_fixture.dart';
import '../wallet_signer_test_fixture.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _TestPathProvider extends PathProviderPlatform {
  final String path;

  _TestPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signs Payjoin at the stored account', () async {
    final directory = Directory.systemTemp.createTempSync('payjoin_account_');
    final originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(directory.path);
    addTearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      directory.deleteSync(recursive: true);
    });
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => directory.path);
    final secret =
        (await secrets.import(words: testMnemonics.first.split(' '))
                as Ok<Secret, SecretFailure>)
            .value;
    final descriptors = singleSignatureDescriptorsAtAccount(
      testMnemonics.first,
      account: 1,
    );
    final descriptor = twoPathDescriptor(
      descriptors.external,
      descriptors.internal,
    );
    final metadata = _MockWalletMetadataDatasource();
    when(() => metadata.fetch('wallet')).thenAnswer(
      (_) async => WalletMetadataModel(
        id: 'wallet',
        network: Network.bitcoinTestnet,
        signers: [
          walletSignerModel(
            id: 'signer-0',
            descriptorKeyId: 'key-0',
            masterFingerprint: secret.id.hex,
            xpubFingerprint: 'deadbeef',
            xpub: descriptors.xpub.split(']').last,
            derivationPath: "m/84'/1'/1'",
            descriptorPath: '/<0;1>/*',
            signer: Signer.local,
            signerDevice: null,
          ),
        ],
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        publicDescriptor: descriptor,
        isDefault: false,
      ),
    );
    final adapter = PayjoinWalletAdapter(
      secrets,
      BdkWalletDatasource(),
      metadata,
    );

    final result = await adapter.signPsbt(
      walletId: 'wallet',
      network: BitcoinNetwork.testnet,
      psbt: buildUnsignedPsbt(descriptor: descriptor),
    );
    final signed = bdk.Psbt(psbtBase64: result);
    try {
      expect(signed.input().single.finalScriptWitness, isNotEmpty);
    } finally {
      signed.dispose();
    }
  });
}
