import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show
        InvalidViewNameFailure,
        LastViewFailure,
        SecretFailure,
        UseSecretFailure,
        ViewHoldsSecretsFailure,
        ViewInUseFailure,
        ViewNotOpenFailure;
import 'package:secrets/storage.dart';

import '../domain/views_failure.dart';
import '../domain/views_port.dart';

/// The views of the live session, through the inventory that owns them.
final class SecretsViewsPort implements ViewsPort {
  final SecretsInventory _inventory;
  final _changes = StreamController<void>.broadcast();
  late final StreamSubscription<bool> _lock;

  SecretsViewsPort(this._inventory) {
    _lock = _inventory.lockedChanges.listen((_) => _changes.add(null));
  }

  @override
  List<ViewSummary> get views => _inventory.openedViews?.views ?? const [];

  @override
  ViewId? get active => _inventory.activeView;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<void, ViewsFailure>> activate(ViewId id) async =>
      _published(await _run((opened) => opened.activate(id)));

  @override
  Future<Result<ViewSummary, ViewsFailure>> create(String name) async =>
      _published(
        await _run((opened) => opened.administration.create(name: name)),
      );

  @override
  Future<Result<void, ViewsFailure>> rename(ViewId id, String name) async =>
      _published(
        await _run((opened) => opened.administration.rename(id, name)),
      );

  @override
  Future<Result<void, ViewsFailure>> delete(ViewId id) async =>
      _published(await _run((opened) => opened.administration.delete(id)));

  @override
  Future<Result<void, ViewsFailure>> setBackground(bool enabled) async =>
      _published(_map(await _inventory.setBackgroundEnabled(enabled)));

  Future<Result<T, ViewsFailure>> _run<T>(
    Future<Result<T, SecretFailure>> Function(OpenedViews opened) action,
  ) async {
    final opened = _inventory.openedViews;
    if (opened == null) return const Err(ViewsUnavailableFailure());
    return _map(await action(opened));
  }

  Result<T, ViewsFailure> _published<T>(Result<T, ViewsFailure> result) {
    if (result is Ok) _changes.add(null);
    return result;
  }

  Result<T, ViewsFailure> _map<T>(Result<T, SecretFailure> result) =>
      switch (result) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => Err(switch (failure) {
          LastViewFailure() => const ViewsLastViewFailure(),
          ViewHoldsSecretsFailure() => const ViewsHoldsSecretsFailure(),
          ViewInUseFailure() => const ViewsInUseFailure(),
          InvalidViewNameFailure() => const ViewsInvalidNameFailure(),
          UseSecretFailure() ||
          ViewNotOpenFailure() => const ViewsUnavailableFailure(),
          _ => const ViewsUnexpectedFailure(),
        }),
      };

  Future<void> close() async {
    await _lock.cancel();
    await _changes.close();
  }
}
