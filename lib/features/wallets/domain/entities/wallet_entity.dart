import 'package:bb_mobile/core/primitives/network/network.dart';
import 'package:bb_mobile/features/wallets/domain/errors/wallet_errors_dart';

class WalletEntity {
  final int? _id;
  String? _label;
  final bool _isDefault;
  final Network _network;
  DateTime? _mnemonicTestedAt;
  DateTime? _encryptedVaultTestedAt;
  DateTime? _syncedAt;
  final DateTime? _birthday;

  WalletEntity._({
    int? id,
    String? label,
    required bool isDefault,
    required Network network,
    DateTime? mnemonicTestedAt,
    DateTime? encryptedVaultTestedAt,
    DateTime? syncedAt,
    DateTime? birthday,
  }) : _id = id,
       _label = label,
       _isDefault = isDefault,
       _network = network,
       _mnemonicTestedAt = mnemonicTestedAt,
       _encryptedVaultTestedAt = encryptedVaultTestedAt,
       _syncedAt = syncedAt,
       _birthday = birthday {
    validate();
  }

  factory WalletEntity.createNew({
    String? label,
    required bool isDefault,
    required Network network,
    DateTime? birthday,
  }) {
    final wallet = WalletEntity._(
      label: label,
      isDefault: isDefault,
      network: network,
      birthday: birthday,
    );

    wallet.validate();

    return wallet;
  }

  factory WalletEntity.rehydrate({
    required int id,
    String? label,
    required bool isDefault,
    required Network network,
    DateTime? mnemonicTestedAt,
    DateTime? encryptedVaultTestedAt,
    DateTime? syncedAt,
    DateTime? birthday,
  }) {
    return WalletEntity._(
      id: id,
      label: label,
      isDefault: isDefault,
      network: network,
      mnemonicTestedAt: mnemonicTestedAt,
      encryptedVaultTestedAt: encryptedVaultTestedAt,
      syncedAt: syncedAt,
      birthday: birthday,
    );
  }

  void validate() {
    if (_isDefault &&
        !(_network == Network.bitcoin || _network == Network.liquid)) {
      throw WrongDefaultWalletNetworkError(network: _network);
    }
  }

  int? get id => _id;
  String? get label => _label;
  bool get isDefault => _isDefault;
  Network get network => _network;
  DateTime? get mnemonicTestedAt => _mnemonicTestedAt;
  DateTime? get encryptedVaultTestedAt => _encryptedVaultTestedAt;
  DateTime? get syncedAt => _syncedAt;
  DateTime? get birthday => _birthday;

  bool get isPersisted => _id != null;

  void setLabel(String label) {
    _label = label;
  }

  void setLatestMnemonicTestDate(DateTime testedAt) {
    if (_mnemonicTestedAt == null || testedAt.isAfter(_mnemonicTestedAt!)) {
      _mnemonicTestedAt = testedAt;
    }
  }

  void setLatestEncryptedVaultTestDate(DateTime testedAt) {
    if (_encryptedVaultTestedAt == null ||
        testedAt.isAfter(_encryptedVaultTestedAt!)) {
      _encryptedVaultTestedAt = testedAt;
    }
  }

  void setLatestSyncDate(DateTime syncedAt) {
    if (_syncedAt == null || syncedAt.isAfter(_syncedAt!)) _syncedAt = syncedAt;
  }
}
