/// A Bitcoin wallet visible in the calling view, with the verdict a metadata
/// backup needs: whether every BIP138 recipient key it would encrypt to is its
/// own, in this view and in every other.
final class BackupCandidate {
  final String walletId;

  /// False when its row is visible in another view or one of its recipient keys
  /// is carried by another wallet. Never backed up, never offered a restore.
  final bool exclusive;

  const BackupCandidate({required this.walletId, required this.exclusive});
}
