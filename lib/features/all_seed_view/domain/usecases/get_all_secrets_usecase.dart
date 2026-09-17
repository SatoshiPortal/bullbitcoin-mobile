import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Every stored secret, as handles, plus how many entries could not be read. Cheap: nothing is derived, nothing is revealed.
class GetAllSecretsUsecase {
  final Secrets _secrets;

  const GetAllSecretsUsecase({required Secrets secrets}) : this._(secrets);

  const GetAllSecretsUsecase._(this._secrets);

  @useResult
  Future<Result<SecretListing<Secret>, SecretFailure>> execute() =>
      _secrets.list();
}
