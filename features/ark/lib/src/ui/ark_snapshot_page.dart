import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../domain/ark_failure.dart';
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
  /// Busy is Ark finishing other work, usually within seconds: the page
  /// never says so, it keeps loading and asks again until Ark answers.
  static const _busyDelay = Duration(seconds: 2);

  late StreamSubscription<ArkViewState> _subscription;
  int _generation = 0;
  Timer? _busyRetry;

  bool _current(ArkCubit owner, int generation) =>
      mounted &&
      generation == _generation &&
      identical(widget.cubit, owner) &&
      !owner.isClosed;

  void _listen() {
    final owner = widget.cubit;
    final generation = ++_generation;
    _subscription = owner.stream.listen((state) {
      if (!_current(owner, generation)) return;
      _retryWhileBusy(owner, generation, state);
      setState(() {});
    });
    unawaited(owner.load()); // The single load owner for snapshot-only pages.
  }

  bool _waitsOnBusy(ArkViewState state) =>
      state is ArkViewFailed && state.failure is ArkOperationBusyFailure;

  void _retryWhileBusy(ArkCubit owner, int generation, ArkViewState state) {
    if (!_waitsOnBusy(state) || _busyRetry != null) return;
    _busyRetry = Timer(_busyDelay, () {
      _busyRetry = null;
      if (_current(owner, generation) && identical(owner.state, state)) {
        unawaited(owner.load());
      }
    });
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
      _busyRetry?.cancel();
      _busyRetry = null;
      unawaited(_subscription.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    ++_generation;
    _busyRetry?.cancel();
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
    if (!_current(owner, generation)) return const ArkUnavailableScreen();
    return switch (owner.state) {
      ArkObserved(:final snapshot) when snapshot.account == owner.account =>
        widget.builder(snapshot),
      ArkObserved() => const ArkUnavailableScreen(),
      // Busy while refreshing: keep what was on screen and retry quietly.
      ArkViewFailed(:final lastObserved?)
          when _waitsOnBusy(owner.state) &&
              lastObserved.account == owner.account =>
        widget.builder(lastObserved),
      final ArkViewFailed failed when _waitsOnBusy(failed) => const _Loading(),
      final ArkViewFailed failed => _Failed(
        failure: failed.failure,
        onRetry: () => _retry(owner, generation, failed),
      ),
      ArkLoading() => const _Loading(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
              child: BullTopBar(
                title: l10n.title,
                onBack: () => Navigator.maybePop(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [const BullLoader.large()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ark could not be read: what happened in a few calm words, and one way on.
class _Failed extends StatelessWidget {
  final ArkFailure failure;
  final VoidCallback onRetry;

  const _Failed({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final colors = context.bull;
    return BullScaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.md,
            BullSpacing.xs,
            BullSpacing.md,
            BullSpacing.lg,
          ),
          child: BullButton.big(
            label: l10n.tryAgain,
            onPressed: onRetry,
            bgColor: colors.inverseSurface,
            textColor: colors.surface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
              child: BullTopBar(
                title: l10n.title,
                onBack: () => Navigator.maybePop(context),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BullSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: BullIcon(
                            BullIcons.errorOutline,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      const Gap(BullSpacing.md),
                      Semantics(
                        header: true,
                        child: BullText(
                          l10n.arkLoadFailedTitle,
                          role: BullTextRole.subtitle,
                          fontWeight: FontWeight.w600,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Gap(BullSpacing.xs),
                      BullText(
                        failure.toTranslated(context),
                        role: BullTextRole.body,
                        color: colors.textMuted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
