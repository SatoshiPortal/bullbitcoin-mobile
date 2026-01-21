enum CopBankAccountTypeViewModel {
  savings(value: 'S'),
  checking(value: 'C');

  final String value;
  const CopBankAccountTypeViewModel({required this.value});
}
