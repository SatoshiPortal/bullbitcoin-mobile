/// The one door by which the trusted Ark integration refreshes VTXOs in the
/// background (D105). Not exported by `package:secrets/secrets.dart`.
///
/// Its single importer is `packages/ark/lib/src/data/ark_renewal_child_provider.dart`:
/// an architecture test fails on any other. It hands over the dedicated BIP85
/// child of one Ark account, never the parent mnemonic.
library;

export 'src/public/ark_renewal_secrets.dart' show ArkRenewalSecrets, ArkChild;
