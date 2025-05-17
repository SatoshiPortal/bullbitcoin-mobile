enum Bip85Bip39Language {
  english(derivationPathValue: "0'"),
  japanese(derivationPathValue: "1'"),
  korean(derivationPathValue: "2'"),
  spanish(derivationPathValue: "3'"),
  chineseSimplified(derivationPathValue: "4'"),
  chineseTraditional(derivationPathValue: "5'"),
  french(derivationPathValue: "6'"),
  italian(derivationPathValue: "7'"),
  czech(derivationPathValue: "8'"),
  portuguese(derivationPathValue: "9'");

  final String derivationPathValue;

  const Bip85Bip39Language({required this.derivationPathValue});
}
