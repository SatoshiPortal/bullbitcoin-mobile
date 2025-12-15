import 'package:bb_mobile/core/infra/database/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/primitives/network/network_environment.dart';
import 'package:bb_mobile/core/primitives/signer/signer_device.dart';
import 'package:drift/drift.dart';

@DataClassName('LiquidWalletConfigRow')
class LiquidWalletConfigs extends Table {
  /// Foreign key to Wallets table
  IntColumn get walletId =>
      integer().references(WalletMetadatas, #id, onDelete: KeyAction.cascade)();
  TextColumn get networkEnvironment => textEnum<LiquidNetworkEnvironment>()();
  TextColumn get masterFingerprint => text()();
  TextColumn get xpub => text()();
  TextColumn get externalPublicDescriptor => text()();
  TextColumn get signer => text()();
  TextColumn get signerDevice => textEnum<SignerDevice>().nullable()();

  @override
  Set<Column> get primaryKey => {walletId};
}
