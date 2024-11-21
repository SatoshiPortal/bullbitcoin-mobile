class KeychainState {
  KeychainState({
    required this.secret,
    required this.secretConfirmed,
  });

  final String secret;
  final bool secretConfirmed;
}
