enum CopBankAcountTypeViewModel {
  savings(value: 'S'),
  checking(value: 'C');

  final String value;
  const CopBankAcountTypeViewModel({required this.value});
}
