import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../public_wallet_descriptor.dart';
import '../transaction_sync_failure.dart';
import '../wallet_key.dart';

abstract interface class WalletCatalogPort {
  @useResult
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>> list();
  @useResult
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  );
}
