import 'package:primitives/primitives.dart';

import '../domain/errors/bip85_failure.dart';

export '../domain/errors/bip85_failure.dart';

/// Resolves the active environment's default Bitcoin parent on each operation.
typedef Bip85ParentReader =
    Future<Result<Fingerprint, Bip85Failure>> Function();
