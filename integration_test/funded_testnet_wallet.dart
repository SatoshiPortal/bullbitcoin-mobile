import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart' show fail;
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:secrets/secrets.dart';

/// Coins and Payjoin use the same Alice account in the aggregated suite.
Future<Wallet> openFundedTestnetWallet({
  required String mnemonic,
  required Secrets secrets,
  required WalletRepository wallets,
}) async {
  final words = mnemonic.split(' ');
  const language = Language.english;
  final existing = switch (await secrets.find(
    words: words,
    language: language,
  )) {
    Ok(:final value) => value,
    Err(:final failure) => fail('secret lookup failed: ${failure.runtimeType}'),
  };
  final secret =
      existing ??
      switch (await secrets.import(words: words, language: language)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('import failed: ${failure.runtimeType}'),
      };

  const network = Network.bitcoinTestnet;
  const scriptType = ScriptType.bip84;
  final id = WalletMetadataService.encodeId(
    fingerprint: secret.id.hex,
    network: network,
    scriptType: scriptType,
  );
  return switch (await wallets.getWallet(id)) {
    Ok(:final value) => value,
    Err(failure: WalletNotFoundFailure()) => await wallets.createWallet(
      secret: secret,
      network: network,
      scriptType: scriptType,
    ),
    Err(:final failure) => fail('wallet lookup failed: ${failure.runtimeType}'),
  };
}
