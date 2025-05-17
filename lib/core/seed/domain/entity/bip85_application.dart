enum Bip85Application {
  bip39(derivationPathValue: "39'");

  final String derivationPathValue;

  const Bip85Application({required this.derivationPathValue});
}
