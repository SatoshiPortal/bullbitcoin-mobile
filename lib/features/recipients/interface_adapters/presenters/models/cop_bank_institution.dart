enum CopBankInstitution {
  bancolombia(code: '007', name: 'Bancolombia');

  final String code;
  final String name;

  const CopBankInstitution({required this.code, required this.name});
}
