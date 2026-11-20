import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/usecases/dismiss_exchange_prompt_usecase.dart';
import '../domain/usecases/load_exchange_prompt_dismissed_usecase.dart';

/// Whether the More sheet invites the user to activate the exchange: offered
/// by the host and never dismissed.
final class ExchangePromptCubit extends Cubit<bool> {
  final LoadExchangePromptDismissedUsecase _load;
  final DismissExchangePromptUsecase _dismiss;
  final void Function(String) _warning;
  late final StreamSubscription<bool> _subscription;
  bool _offered = false;
  bool? _dismissed;

  ExchangePromptCubit({
    required this._load,
    required this._dismiss,
    required this._warning,
    required Stream<bool> offered,
  }) : super(false) {
    _subscription = offered.listen((value) {
      _offered = value;
      _publish();
    });
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final result = await _load.execute();
    if (_dismissed != null) return;
    switch (result) {
      case Ok(:final value):
        _dismissed = value;
      case Err():
        _warning('Could not read the exchange prompt preference; hiding it');
        _dismissed = true;
    }
    _publish();
  }

  void _publish() {
    if (!isClosed) emit(_offered && _dismissed == false);
  }

  Future<void> dismiss() async {
    _dismissed = true;
    _publish();
    if (await _dismiss.execute() case Err()) {
      _warning('Could not save the exchange prompt dismissal');
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
