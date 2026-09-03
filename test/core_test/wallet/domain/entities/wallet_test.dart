import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Wallet wallet({
    String? derivationPath = "m/84'/0'/0'",
    String publicDescriptor = 'wpkh(xpub/<0;1>/*)',
    String descriptorPath = '/<0;1>/*',
    ScriptType? scriptType = ScriptType.bip84,
    SignerEntity signer = SignerEntity.local,
    SignerDeviceEntity? signerDevice,
    int descriptorKeyCount = 1,
  }) {
    return Wallet(
      origin: 'wallet',
      network: Network.bitcoinMainnet,
      signers: [
        WalletSigner(
          id: 'signer-0',
          signer: signer,
          signerDevice: signerDevice,
          descriptorKeys: [
            for (var index = 0; index < descriptorKeyCount; index++)
              WalletDescriptorKey(
                id: 'key-$index',
                signerId: 'signer-0',
                masterFingerprint: '00000000',
                xpubFingerprint: '00000000',
                xpub: 'xpub-$index',
                derivationPath: derivationPath,
                descriptorPath: descriptorPath,
              ),
          ],
        ),
      ],
      scriptType: scriptType,
      publicDescriptor: publicDescriptor,
      balanceSat: BigInt.zero,
    );
  }

  group('Wallet.isStandardLocalSingleSignatureWallet', () {
    test('accepts standard apostrophe and h hardened paths', () {
      expect(wallet().isStandardLocalSingleSignatureWallet, isTrue);
      expect(
        wallet(
          derivationPath: 'm/84h/0h/0h',
        ).isStandardLocalSingleSignatureWallet,
        isTrue,
      );
    });

    test('rejects a nonstandard descriptor keychain', () {
      expect(
        wallet(
          publicDescriptor: 'wpkh(xpub/<2;3>/*)',
          descriptorPath: '/<2;3>/*',
        ).isStandardLocalSingleSignatureWallet,
        isFalse,
      );
    });

    test('rejects derivation before the receive/change keychain', () {
      expect(
        wallet(
          publicDescriptor: 'wpkh(xpub/0/<0;1>/*)',
          descriptorPath: '/0/<0;1>/*',
        ).isStandardLocalSingleSignatureWallet,
        isFalse,
      );
    });

    test('rejects an arbitrary descriptor policy', () {
      expect(
        wallet(
          scriptType: null,
          publicDescriptor: 'wsh(pk(xpub/<0;1>/*))',
        ).isStandardLocalSingleSignatureWallet,
        isFalse,
      );
    });

    test('rejects a remote signer', () {
      expect(
        wallet(
          signer: SignerEntity.remote,
        ).isStandardLocalSingleSignatureWallet,
        isFalse,
      );
    });
  });

  test('has no derivation path when the descriptor has no key origin', () {
    expect(
      wallet(
        derivationPath: null,
        scriptType: null,
        publicDescriptor: 'wsh(pk(xpub/<0;1>/*))',
      ).derivationPath,
      isNull,
    );
    expect(wallet(derivationPath: null).derivationPath, isNull);
  });

  group('Wallet.isStandardSingleSignatureWallet', () {
    test('accepts higher accounts for local and remote signers', () {
      expect(
        wallet(derivationPath: "m/84'/0'/1'").isStandardSingleSignatureWallet,
        isTrue,
      );
      expect(
        wallet(
          derivationPath: 'm/84h/0h/1h',
          signer: SignerEntity.remote,
        ).isStandardSingleSignatureWallet,
        isTrue,
      );
    });

    test('rejects arbitrary descriptor policies', () {
      expect(
        wallet(
          scriptType: null,
          publicDescriptor: 'wsh(pk(xpub/<0;1>/*))',
        ).isStandardSingleSignatureWallet,
        isFalse,
      );
    });
  });

  test('supports descriptor Send when at least one signer is available', () {
    expect(
      wallet(
        scriptType: null,
        publicDescriptor: 'wsh(pk(xpub/<0;1>/*))',
      ).supportsSend,
      isTrue,
    );
    expect(
      wallet(
        scriptType: null,
        publicDescriptor: 'wsh(pk(xpub/<0;1>/*))',
        signer: SignerEntity.none,
      ).supportsSend,
      isFalse,
    );
  });

  group('Wallet.isStandardSingleSignatureWallet', () {
    test('does not depend on whether the signer is local or remote', () {
      expect(wallet().isStandardSingleSignatureWallet, isTrue);
      expect(
        wallet(signer: SignerEntity.remote).isStandardSingleSignatureWallet,
        isTrue,
      );
    });
  });

  test('keeps device signing within supported Taproot policies', () {
    final mk4 = wallet(
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.coldcardMk4,
    );
    final q = wallet(
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.coldcardQ,
    );
    final taprootMk4 = wallet(
      publicDescriptor: 'tr(xpub/<0;1>/*)',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.coldcardMk4,
    );
    final taprootQ = wallet(
      publicDescriptor: 'tr(xpub/<0;1>/*)',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.coldcardQ,
    );
    final taprootScriptMk4 = wallet(
      publicDescriptor: 'tr(xpub/<0;1>/*,pk(xpub/<0;1>/*))',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.coldcardMk4,
    );
    final taprootPassport = wallet(
      publicDescriptor: 'tr(xpub/<0;1>/*)',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.passport,
    );
    final taprootScriptPassport = wallet(
      publicDescriptor: 'tr(xpub/<0;1>/*,pk(xpub/<0;1>/*))',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.passport,
    );

    expect(mk4.supportsQrSigningFor(mk4.signers.single), isFalse);
    expect(mk4.supportsDevicePsbtFlowFor(mk4.signers.single), isTrue);
    expect(q.supportsQrSigningFor(q.signers.single), isTrue);
    expect(q.supportsDevicePsbtFlowFor(q.signers.single), isTrue);
    expect(
      taprootMk4.supportsDevicePsbtFlowFor(taprootMk4.signers.single),
      isFalse,
    );
    expect(
      taprootQ.supportsDevicePsbtFlowFor(taprootQ.signers.single),
      isFalse,
    );
    expect(
      taprootScriptMk4.supportsDevicePsbtFlowFor(
        taprootScriptMk4.signers.single,
      ),
      isFalse,
    );
    expect(
      taprootPassport.supportsQrSigningFor(taprootPassport.signers.single),
      isTrue,
    );
    expect(
      taprootScriptPassport.supportsQrSigningFor(
        taprootScriptPassport.signers.single,
      ),
      isFalse,
    );
  });

  test('offers BitBox policies for only one controlled account key', () {
    final singleAccount = wallet(
      publicDescriptor: 'wsh(pk(xpub/<0;1>/*))',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.bitbox02,
    );
    final multipleAccounts = wallet(
      publicDescriptor: 'wsh(or_d(pk(xpub-a/<0;1>/*),pk(xpub-b/<0;1>/*)))',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.bitbox02,
      descriptorKeyCount: 2,
    );
    final hashlock = wallet(
      publicDescriptor:
          'wsh(and_v(v:pk(xpub/<0;1>/*),sha256(0000000000000000000000000000000000000000000000000000000000000000)))',
      scriptType: null,
      signer: SignerEntity.remote,
      signerDevice: SignerDeviceEntity.bitbox02,
    );

    expect(
      singleAccount.supportsWalletPolicySigner(singleAccount.signers.single),
      isTrue,
    );
    expect(
      multipleAccounts.supportsWalletPolicySigner(
        multipleAccounts.signers.single,
      ),
      isFalse,
    );
    expect(
      hashlock.supportsWalletPolicySigner(hashlock.signers.single),
      isFalse,
    );
  });
}
