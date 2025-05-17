enum Bip85Bip39WordCount {
  twelve(derivationPathValue: "12'"),
  fifteen(derivationPathValue: "15'"),
  eighteen(derivationPathValue: "18'"),
  twentyOne(derivationPathValue: "21'"),
  twentyFour(derivationPathValue: "24'");

  final String derivationPathValue;

  const Bip85Bip39WordCount({required this.derivationPathValue});
}
