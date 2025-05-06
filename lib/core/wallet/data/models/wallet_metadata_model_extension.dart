import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';

extension WalletMetadataModelExtension on WalletMetadataModel {
  ({String account, String fingerprint, Network network, ScriptType script})
  get decodeOrigin => WalletMetadataService.decodeOrigin(origin: id);

  String get account => decodeOrigin.account;
  String get fingerprint => decodeOrigin.fingerprint;
  Network get network => decodeOrigin.network;
  ScriptType get scriptType => decodeOrigin.script;
  bool get isBitcoin => decodeOrigin.network.isBitcoin;
  bool get isLiquid => decodeOrigin.network.isLiquid;
  bool get isMainnet => decodeOrigin.network.isMainnet;
  bool get isTestnet => decodeOrigin.network.isTestnet;
}
