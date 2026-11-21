import 'package:signers/src/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:signers/src/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:signers/src/signer_device_entity.dart';
import 'package:signers/src/ledger/domain/entities/ledger_device_entity.dart';
import 'package:signers/src/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:signers/src/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:signers/src/ledger/domain/usecases/verify_address_ledger_usecase.dart';
import 'package:signers/src/bitbox_flow/domain/read_bitbox_account_usecase.dart';
import 'package:signers/src/bitbox_flow/domain/sign_psbt_bitbox_usecase.dart';
import 'package:signers/src/bitbox_flow/domain/verify_address_bitbox_usecase.dart';
import 'package:signers/src/ledger_flow/domain/read_ledger_account_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Ledger extends Mock implements LedgerDeviceRepository {}

class _BitBox extends Mock implements BitBoxDeviceRepository {}

const _ledger = LedgerDeviceEntity(
  id: 'ledger',
  name: 'Ledger',
  connectionType: LedgerConnectionType.usb,
  deviceType: SignerDeviceEntity.ledgerNanoSPlus,
);
const _bitbox = BitBoxDeviceEntity(
  deviceName: 'BitBox',
  serialNumber: 'test',
  product: 'bitbox02',
  connectionType: BitBoxConnectionType.usb,
);

void main() {
  for (final network in [NetworkEnv.regtest, NetworkEnv.signet]) {
    test(
      '$network refuses reading, signing and verification before device IO',
      () async {
        final ledger = _Ledger();
        final bitbox = _BitBox();
        final results = [
          await ReadLedgerAccountUsecase(repository: ledger)
              .execute(network: network, device: _ledger),
          await ReadBitBoxAccountUsecase(repository: bitbox)
              .execute(network: network, device: _bitbox),
          await SignPsbtLedgerUsecase(repository: ledger).execute(
            _ledger,
            network: network,
            psbt: 'psbt',
            derivationPath: "m/84'/1'/0'",
            scriptType: ScriptType.bip84,
          ),
          await SignPsbtBitBoxUsecase(repository: bitbox).execute(
            _bitbox,
            network: network,
            psbt: 'psbt',
            derivationPath: "m/84'/1'/0'",
            scriptType: ScriptType.bip84,
          ),
          await VerifyAddressLedgerUsecase(repository: ledger).execute(
            device: _ledger,
            network: network,
            address: 'address',
            derivationPath: "m/84'/1'/0'/0/0",
            scriptType: ScriptType.bip84,
          ),
          await VerifyAddressBitBoxUsecase(repository: bitbox).execute(
            device: _bitbox,
            network: network,
            address: 'address',
            derivationPath: "m/84'/1'/0'/0/0",
            scriptType: ScriptType.bip84,
          ),
        ];
        for (final result in results) {
          expect(result, isA<Err>());
        }
        verifyZeroInteractions(ledger);
        verifyZeroInteractions(bitbox);
      },
    );
  }
  for (final network in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
    test(
      'reads the requested $network account and preserves its identity',
      () async {
        final ledger = _Ledger();
        final bitbox = _BitBox();
        final path = "m/49'/${network == NetworkEnv.mainnet ? 0 : 1}'/3'";
        when(() => ledger.getMasterFingerprint(_ledger))
            .thenAnswer((_) async => const Ok('aabbccdd'));
        when(() => bitbox.getMasterFingerprint(_bitbox))
            .thenAnswer((_) async => const Ok('aabbccdd'));
        when(
          () => ledger.getXpub(
            _ledger,
            derivationPath: path,
            scriptType: ScriptType.bip49,
          ),
        ).thenAnswer((_) async => const Ok('public-account'));
        when(
          () => bitbox.getXpub(
            _bitbox,
            derivationPath: path,
            scriptType: ScriptType.bip49,
            isTestnet: network == NetworkEnv.testnet,
          ),
        ).thenAnswer((_) async => const Ok('public-account'));
        final results = [
          await ReadLedgerAccountUsecase(repository: ledger).execute(
            device: _ledger,
            network: network,
            scriptType: ScriptType.bip49,
            account: 3,
          ),
          await ReadBitBoxAccountUsecase(repository: bitbox).execute(
            device: _bitbox,
            network: network,
            scriptType: ScriptType.bip49,
            account: 3,
          ),
        ];
        for (final result in results) {
          final account = (result as Ok).value;
          expect(account.network, network);
          expect(account.derivationPath, path);
          expect(account.scriptType, ScriptType.bip49);
          expect(account.masterFingerprint, 'aabbccdd');
          expect(account.xpub, 'public-account');
        }
      },
    );
  }
}
