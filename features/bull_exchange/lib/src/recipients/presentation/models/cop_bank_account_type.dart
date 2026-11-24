enum CopBankAccountType {
  savings(value: 'S'),
  checking(value: 'C');

  final String value;
  const CopBankAccountType({required this.value});
}
