import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;

import 'address_view_failure.dart';
import 'wallet_address.dart';

abstract interface class WalletAddressRepository {
  @useResult
  Future<Result<WalletAddress, AddressViewFailure>> at(
    WalletKey key,
    int index,
  );

  @useResult
  Future<Result<WalletAddress, AddressViewFailure>> receive(
    WalletKey key, {
    required bool advance,
  });

  @useResult
  Future<Result<List<WalletAddress>, AddressViewFailure>> list(
    WalletKey key, {
    required bool change,
    int? limit,
    int? fromIndex,
  });

  Future<WalletAddress> attachLabels(WalletAddress address);
}
