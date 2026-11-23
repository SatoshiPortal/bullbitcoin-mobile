import 'package:primitives/primitives.dart';

import '../public/bip85_parent.dart';

/// Resolves the parent at operation time, before any secret is read.
class WithDefaultBip85WalletUsecase {
  final Bip85ParentReader _readParent;

  const WithDefaultBip85WalletUsecase(this._readParent);

  Future<Result<T, Bip85Failure>> execute<T>(
    Future<Result<T, Bip85Failure>> Function(Fingerprint) operation,
  ) async {
    return switch (await _readParent()) {
      Ok(:final value) => operation(value),
      Err(:final failure) => Err(failure),
    };
  }
}
