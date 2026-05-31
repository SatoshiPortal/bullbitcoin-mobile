abstract interface class TransactionExportSaver {
  Future<bool> save(String csv);
}
