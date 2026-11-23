import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class WalletSecretReferencesRepository {
  @useResult
  Future<Result<List<Fingerprint>, WalletFailure>> list();
}
