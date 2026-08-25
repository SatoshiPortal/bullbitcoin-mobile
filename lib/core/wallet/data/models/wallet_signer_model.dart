import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_signer_model.freezed.dart';

@freezed
abstract class WalletSignerModel with _$WalletSignerModel {
  const factory WalletSignerModel({
    required String id,
    required Signer signer,
    required SignerDevice? signerDevice,
    required List<WalletDescriptorKeyModel> descriptorKeys,
  }) = _WalletSignerModel;
}
