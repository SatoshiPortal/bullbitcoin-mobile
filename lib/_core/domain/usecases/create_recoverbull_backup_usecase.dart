import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';

class CreateRecoverBullBackupUsecase {
  final RecoverBullRepository _repository;

  CreateRecoverBullBackupUsecase({required RecoverBullRepository repository})
      : _repository = repository;

  Future<String> execute() async {
    // TODO: get XPRV from next Bram PR and pass it
    //     // TODO: Usecase should consume BDK repository and inject it when Bram PR will be merged into refactoring-bloc
    //     // final descriptorSecretKey = await DescriptorSecretKey.create(
    //     //   network: network == 'mainnet' ? Network.bitcoin : Network.testnet,
    //     //   mnemonic: await Mnemonic.fromString(mnemonic.join(' ')),
    //     // );
    //     // final xprv = descriptorSecretKey.toString().split('/*').first;

    String xprv = '';
    return _repository.createBackupFile(xprv);
  }
}
