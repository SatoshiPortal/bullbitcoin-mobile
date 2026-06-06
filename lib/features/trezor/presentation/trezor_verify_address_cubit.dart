import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/application/usecases/verify_address_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_base_cubit.dart';

class TrezorVerifyAddressCubit extends TrezorOperationBaseCubit<bool> {
  final VerifyAddressTrezorUsecase _verifyAddress;

  TrezorVerifyAddressCubit({required VerifyAddressTrezorUsecase verifyAddress})
    : _verifyAddress = verifyAddress;

  Future<void> verify({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) {
    return runOperation(
      () => _verifyAddress.execute(
        address: address,
        derivationPath: derivationPath,
        scriptType: scriptType,
        isTestnet: isTestnet,
      ),
    );
  }
}
