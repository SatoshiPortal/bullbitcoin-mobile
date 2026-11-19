import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import 'ark_unavailable_screen.dart';

/// Owns one read trigger/subscription, never the caller's controller lifetime.
class ArkSnapshotPage extends StatefulWidget {
  final ArkCubit cubit;
  final Widget Function(ArkSnapshot) builder;
  const ArkSnapshotPage({
    super.key,
    required this.cubit,
    required this.builder,
  });
  @override
  State<ArkSnapshotPage> createState() => _ArkSnapshotPageState();
}

class _ArkSnapshotPageState extends State<ArkSnapshotPage> {
  late StreamSubscription<ArkViewState> _subscription;
  int _generation = 0;
  bool _current(ArkCubit owner, int generation) =>
      mounted &&
      generation == _generation &&
      identical(widget.cubit, owner) &&
      !owner.isClosed;
  void _listen() {
    final owner = widget.cubit;
    final generation = ++_generation;
    _subscription = owner.stream.listen((_) {
      if (_current(owner, generation)) setState(() {});
    });
    unawaited(owner.load()); // The single load owner for snapshot-only pages.
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ArkSnapshotPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _retry(ArkCubit owner, int generation, ArkViewFailed rendered) {
    if (_current(owner, generation) && identical(owner.state, rendered)) {
      unawaited(owner.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.cubit;
    final generation = _generation;
    final l10n = arkLocalizationsOf(context);
    if (!_current(owner, generation)) return const ArkUnavailableScreen();
    return switch (owner.state) {
      ArkObserved(:final snapshot) when snapshot.account == owner.account =>
        widget.builder(snapshot),
      ArkObserved() => const ArkUnavailableScreen(),
      final ArkViewFailed failed => BullScaffold(
        body: SafeArea(
          child: Column(
            children: [
              BullTopBar(
                title: l10n.title,
                onBack: () => Navigator.pop(context),
              ),
              BullInfoBar(message: failed.failure.toTranslated(context)),
              BullButton.big(
                label: l10n.retry,
                onPressed: () => _retry(owner, generation, failed),
                bgColor: context.bull.primary,
                textColor: context.bull.onPrimary,
              ),
            ],
          ),
        ),
      ),
      ArkLoading() => BullScaffold(
        body: Center(child: BullText(l10n.loading, style: null)),
      ),
    };
  }
}
