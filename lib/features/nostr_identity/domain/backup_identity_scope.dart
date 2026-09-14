/// Which of the credential's two signing identities an operation uses.
///
/// One credential, two scalars: the public artifact author and the private
/// server account are deliberately not the same public key (decision 6).
enum BackupIdentityScope { nostr, server }
