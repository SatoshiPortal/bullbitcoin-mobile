import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';

abstract class WalletRepository {
  String get id;
  Network get network;
  Future<void> sync({
    required String blockchainUrl,
    String? socks5,
    int retry = 5,
    int? timeout = 15,
    required BigInt stopGap,
    bool validateDomain = true,
  });
  Future<Balance> getBalance();
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
  Future<Address> getNewAddress();
}
