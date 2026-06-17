import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/domain/usecases/sign_psbt_trezor_usecase.dart';
import 'package:bb_mobile/features/trezor/presentation/trezor_operation_base_cubit.dart';

class TrezorSignTransactionCubit extends TrezorOperationBaseCubit<String> {
  final SignPsbtTrezorUsecase _signPsbt;

  TrezorSignTransactionCubit({required this._signPsbt});

  Future<void> sign({
    required String psbt,
    required bool isTestnet,
    required ScriptType scriptType,
  }) {
    return runOperation(
      () => _signPsbt.execute(
        psbtBase64: psbt,
        isTestnet: isTestnet,
        scriptType: scriptType,
      ),
    );
  }
}
