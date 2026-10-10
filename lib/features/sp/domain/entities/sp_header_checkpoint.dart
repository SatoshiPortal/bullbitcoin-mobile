/// A known block the SP header chain is pinned to.
class SpHeaderCheckpoint {
  static final RegExp _blockHash = RegExp(r'^[0-9a-f]{64}$');

  final int height;
  final String hash;

  SpHeaderCheckpoint({required this.height, required this.hash}) {
    if (height < 0) {
      throw ArgumentError.value(height, 'height', 'must not be negative');
    }
    if (!_blockHash.hasMatch(hash)) {
      throw ArgumentError.value(
        hash,
        'hash',
        'must be 64 lowercase hex characters',
      );
    }
  }
}
