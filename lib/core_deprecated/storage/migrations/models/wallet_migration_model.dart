import 'package:bb_mobile/core/primitives/signer/signer.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_migration_model.freezed.dart';

@freezed
sealed class WalletMigrationModel with _$WalletMigrationModel {
  const factory WalletMigrationModel({
    @Default('') String mnemonic,
    @Default('') String passphrase,
    @Default('') String externalPublicDescriptor,
    @Default('') String internalPublicDescriptor,
    required bool isDefault,
    required Network network,
    required Signer signer,
    required ScriptType scriptType,
    String? label,
  }) = _WalletMigrationModel;
  const WalletMigrationModel._();
}
