/// The one door by which the trusted Ark integration refreshes VTXOs in the
/// background (D105). Not exported by `package:secrets/secrets.dart`.
///
/// Its single importer is `features/ark/lib/src/data/ark_renewal_client.dart`:
/// an architecture test fails on any other. It hands the dedicated BIP85 child
/// of one Ark account to a fixed consumer, never the parent mnemonic.
library;

export 'src/public/ark_renewal_secrets.dart'
    show ArkRenewalSecrets, ArkChild, ArkChildConsumer, ArkChildAdmission;
