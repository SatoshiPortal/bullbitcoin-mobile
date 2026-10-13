import 'package:bull_recoverbull/src/data/mappers/encrypted_vault_mapper.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:primitives/primitives.dart';

Future<Result<EncryptedVault, RecoverBullFailure>> discoveryVault(
  Future<String> Function() fetch,
) async {
  final String content;
  try {
    content = await fetch();
  } on Exception {
    return const Err(RecoverBullGoogleDriveFetchFailure());
  }
  try {
    return Ok(EncryptedVaultMapper.parse(content));
  } on Exception {
    return const Err(InvalidVaultFileFailure());
  }
}
