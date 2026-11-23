import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/watch_only_input.dart';

typedef ProvisionMnemonicWallet =
    Future<Result<void, ParentCustodyFailure>> Function({
      required Fingerprint parent,
      required Secrets secrets,
      required ParentCustodyAdmissionPort admission,
      required BitcoinNetwork network,
      required ScriptType scriptType,
      String? label,
    });

typedef ProvisionDescriptorWallet =
    Future<Result<void, ImportWatchOnlyFailure>> Function({
      required WatchOnlyDescriptorInput descriptor,
      required SignerEntity signer,
      required String label,
    });

typedef ProvisionXpubWallet =
    Future<Result<void, ImportWatchOnlyFailure>> Function({
      required String xpub,
      required BitcoinNetwork network,
      required ScriptType scriptType,
      required String label,
    });
