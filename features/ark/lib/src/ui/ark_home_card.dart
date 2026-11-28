import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../ark_foreground_host.dart';
import '../presentation/ark_home_cubit.dart';
import '../presentation/ark_l10n.dart';
import '../public/ark_navigation.dart';

/// Observes the selected Home source without opening Ark or a funding runtime.
class ArkHomeCard extends StatefulWidget {
  final ArkForegroundHost host;
  final int refresh;
  final Widget Function(
    BuildContext context, {
    required String title,
    required String description,
    required int balanceSat,
    required bool isSyncing,
    required VoidCallback onTap,
  })
  buildCard;

  /// The source wallet this card belongs to, for its remembered balance.
  final String scope;
  const ArkHomeCard({
    super.key,
    required this.host,
    required this.refresh,
    required this.scope,
    required this.buildCard,
  });
  @override
  State<ArkHomeCard> createState() => _ArkHomeCardState();
}

class _ArkHomeCardState extends State<ArkHomeCard> with WidgetsBindingObserver {
  late ArkHomeCubit _owner;

  /// The balance shown last time, until Ark has one of its own.
  Sats? _remembered;
  late StreamSubscription<Object?> _subscription;
  late StreamSubscription<void> _changes;

  void _listen() {
    final owner = ArkHomeCubit(widget.host.homeObservation);
    _owner = owner;
    _subscription = owner.stream.listen((_) {
      if (mounted && identical(owner, _owner)) setState(() {});
    });
    // Ark opens after home on a cold start: show its balance as soon as it
    // is ready, not only after a navigation.
    // A retired runtime makes this read answer nothing at once, so keeping
    // the last balance meanwhile never shows another account's.
    _changes = widget.host.homeChanges.listen((_) {
      if (mounted && identical(owner, _owner)) {
        unawaited(owner.load(keep: true));
      }
    });
    unawaited(owner.load());
    unawaited(_readRemembered(owner));
  }

  Future<void> _readRemembered(ArkHomeCubit owner) async {
    final value = await widget.host.lastHomeBalance(widget.scope);
    if (!mounted ||
        !identical(owner, _owner) ||
        value == null ||
        owner.state?.spendable != null) {
      return;
    }
    setState(() => _remembered = value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(ArkHomeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.host, widget.host) ||
        oldWidget.scope != widget.scope) {
      unawaited(_subscription.cancel());
      unawaited(_changes.cancel());
      unawaited(_owner.close());
      _remembered = null;
      _listen();
    } else if (oldWidget.refresh != widget.refresh) {
      unawaited(_owner.load(keep: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    unawaited(_changes.cancel());
    unawaited(_owner.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_owner.load(keep: true));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BullSpacing.sm,
      BullSizes.homeCardGap,
      BullSpacing.sm,
      BullSpacing.md,
    ),
    child: _card(context),
  );

  void _open() {
    final snapshot = _owner.state;
    if (snapshot == null || snapshot.stale) {
      ArkNavigation.open(context);
    } else {
      ArkNavigation.account(context, snapshot.account);
    }
  }

  /// The same card as every other wallet on home, never "unavailable":
  /// Ark's balance, or while Ark opens or syncs the last one shown, with
  /// the syncing bar. Only before any balance was ever seen is it left out.
  Widget _card(BuildContext context) {
    final snapshot = _owner.state;
    final live = snapshot?.spendable;
    if (live != null && live != _remembered) {
      _remembered = live;
      unawaited(widget.host.rememberHomeBalance(widget.scope, live));
    }
    final balance = live ?? _remembered;
    if (balance == null) return const SizedBox.shrink();
    final l10n = arkLocalizationsOf(context);
    return widget.buildCard(
      context,
      title: l10n.title,
      description: l10n.arkWalletSubtitle,
      balanceSat: balance.value.toInt(),
      isSyncing: live == null || snapshot == null || snapshot.stale,
      onTap: _open,
    );
  }
}
