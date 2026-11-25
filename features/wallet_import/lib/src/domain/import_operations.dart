import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

typedef ProvisionMnemonicWallet =
    Future<Result<void, ParentCustodyFailure>> Function({
      required Fingerprint parent,
      required Secrets secrets,
      required ParentCustodyAdmissionPort admission,
      required BitcoinNetwork network,
      required ScriptType scriptType,
      String? label,
    });
