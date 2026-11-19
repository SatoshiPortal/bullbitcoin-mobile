import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../domain/repositories/ark_account_registry_repository.dart';
import '../domain/ark_child_collision_port.dart';
import '../domain/ark_parent_presence_port.dart';
import '../domain/ark_failure.dart';
import '../domain/ark_provisioning_port.dart';

final class ArkCustodyProvisioner implements ArkProvisioningPort {
  final ParentCustodyAdmissionPort _admission;
  final ArkParentPresencePort _parent;
  final ArkAccountRegistryRepository _registry;
  final ArkChildCollisionPort _collisions;
  const ArkCustodyProvisioner(
    this._admission,
    this._parent,
    this._registry,
    this._collisions,
  );
  @override
  Future<Result<ArkSnapshot, ArkFailure>> run(
    ArkAccountConfig config,
    Future<Result<ArkSnapshot, ArkFailure>> Function() create,
  ) async {
    final admitted = await _admission
        .runExclusive<Result<ArkSnapshot, ArkFailure>>(config.id.parent, (
          lease,
        ) async {
          switch (lease.readState()) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: ParentCustodyState.ready):
              break;
            case Ok():
              return const Err(ParentCustodyStateFailure());
          }
          switch (await _parent.verifyPresent(config.id.parent)) {
            case Err():
              return const Ok(Err(ArkAccountRecoveryFailure()));
            case Ok():
              break;
          }
          switch (await _collisions.hasCollision(config.id.parent)) {
            case Err(:final failure):
              return Ok(Err(failure));
            case Ok(value: true):
              return const Ok(Err(ArkChildCollisionFailure()));
            case Ok():
              break;
          }
          final published = await _registry.publish(config);
          if (published case Err(:final failure)) return Ok(Err(failure));
          // Reference is committed before package locks/native calls. Never remove
          // it on failure: the native account may already contain recoverable work.
          return Ok(await create());
        });
    return switch (admitted) {
      Ok(:final value) => value,
      Err(failure: ParentCustodyBusyFailure()) => const Err(
        ArkOperationBusyFailure(),
      ),
      Err() => const Err(ArkFeatureStorageFailure()),
    };
  }
}
