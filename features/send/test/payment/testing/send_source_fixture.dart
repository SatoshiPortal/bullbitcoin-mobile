import 'package:send/src/payment/domain/send_source.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:signers/signers.dart' show SignerDevice;

SendSource sendSourceFixture({
  String id = 'w1',
  Network network = BitcoinNetwork.mainnet,
  BigInt? balanceSat,
  bool isDefault = false,
  ScriptType scriptType = ScriptType.bip84,
  WalletSigner signer = WalletSigner.local,
  SignerDevice? signerDevice,
  String? derivationPath,
  String? label,
}) => SendSource(
  walletRegistrationForTesting(
    id: id,
    network: network,
    isDefault: isDefault,
    scriptType: scriptType,
    signer: signer,
    derivationPath: derivationPath,
    label: label,
  ),
  balanceSat,
  signerDevice,
);
