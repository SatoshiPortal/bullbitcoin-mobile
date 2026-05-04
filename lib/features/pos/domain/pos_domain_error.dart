sealed class PosDomainError implements Exception {
  const PosDomainError(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosKeyDerivationFailure extends PosDomainError {
  const PosKeyDerivationFailure(super.message);
}

class PosRelayQuorumFailure extends PosDomainError {
  const PosRelayQuorumFailure({required this.reached, required this.required})
    : super('Published to $reached relays, required $required.');

  final int reached;
  final int required;
}

class PosPairingTimeout extends PosDomainError {
  const PosPairingTimeout() : super('Pairing announcement was not found.');
}

class PosAuthorizationFailure extends PosDomainError {
  const PosAuthorizationFailure(super.message);
}

class PosEventDecryptionFailure extends PosDomainError {
  const PosEventDecryptionFailure(super.message);
}

class PosRecoveryClaimFailure extends PosDomainError {
  const PosRecoveryClaimFailure({required this.swapId, required String reason})
    : super('Recovery claim failed for $swapId: $reason.');

  final String swapId;
}
