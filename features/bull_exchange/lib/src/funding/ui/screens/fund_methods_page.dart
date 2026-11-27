import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/funding/domain/fund_event.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow_l10n.dart';
import 'package:bull_exchange/src/funding/presentation/funding_rail_copy.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_jurisdiction_dropdown.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_method_list_tile.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_restricted_card.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullFadingLinearProgress, BullText, BullTypographyX, Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// What the bottom page of the fund flow shows.
sealed class FundMethodsView {
  const FundMethodsView();
}

/// The account is being read, or its read failed ([problem]).
final class FundMethodsLoading extends FundMethodsView {
  final ReadProblem? problem;

  const FundMethodsLoading(this.problem);
}

final class FundMethodsRestricted extends FundMethodsView {
  const FundMethodsRestricted();
}

/// The tiles of [jurisdiction]. [busy] while a tap is being answered;
/// [problem] when the COP bank list could not be read.
final class FundMethodsPicking extends FundMethodsView {
  final Jurisdiction? jurisdiction;
  final List<FundingRail> rails;
  final bool busy;
  final ReadProblem? problem;

  const FundMethodsPicking(
    this.jurisdiction,
    this.rails, {
    this.busy = false,
    this.problem,
  });
}

/// The fund flow's first page: the account load, the restricted card, or
/// the jurisdiction and its rail tiles.
class FundMethodsPage extends StatelessWidget {
  const FundMethodsPage({super.key, required this.view, required this.onEvent});

  final FundMethodsView view;
  final void Function(FundFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    final view = this.view;
    final busy = switch (view) {
      FundMethodsLoading(problem: null) => true,
      FundMethodsPicking(:final busy) => busy,
      FundMethodsLoading() || FundMethodsRestricted() => false,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.fundExchangeTitle),
        leading: BackButton(onPressed: () => onEvent(const FundBackPressed())),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BullFadingLinearProgress(
            height: 3,
            trigger: busy,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Gap(24.0),
              CircleAvatar(
                radius: 32,
                backgroundColor: context.appColors.surfaceContainer,
                child: Icon(
                  Icons.account_balance,
                  size: 24,
                  color: context.appColors.onSurface,
                ),
              ),
              const Gap(8.0),
              BullText(
                context.loc.fundExchangeAccountTitle,
                style: context.bullType.headline,
              ),
              const Gap(8.0),
              ...switch (view) {
                FundMethodsLoading(problem: null) => const <Widget>[],
                FundMethodsLoading(:final problem?) => [
                  const Gap(16.0),
                  BullText(
                    fundReadProblemMessage(
                      context,
                      problem,
                      otherwise: context.loc.oopsSomethingWentWrong,
                    ),
                    style: context.bullType.body,
                    color: Theme.of(context).colorScheme.error,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(16.0),
                  BullButton.primary(
                    label: context.loc.retry,
                    onPressed: () => onEvent(const FundRetryPressed()),
                  ),
                ],
                FundMethodsRestricted() => const [
                  Gap(16.0),
                  FundExchangeRestrictedCard(),
                ],
                FundMethodsPicking() => _picking(context, view),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _picking(BuildContext context, FundMethodsPicking view) => [
    BullText(
      context.loc.fundExchangeAccountSubtitle,
      style: context.bullType.subtitle.copyWith(fontWeight: FontWeight.w400),
    ),
    const Gap(24.0),
    FundExchangeJurisdictionDropdown(
      value: view.jurisdiction,
      onChanged: (jurisdiction) =>
          onEvent(FundJurisdictionPicked(jurisdiction)),
    ),
    const Gap(24.0),
    for (final (index, rail) in view.rails.indexed) ...[
      if (index > 0) const Gap(16.0),
      Builder(
        builder: (context) {
          final tile = rail.tile(context);
          return FundExchangeMethodListTile(
            title: tile.title,
            subtitle: tile.subtitle,
            onTap: view.busy ? null : () => onEvent(FundRailPicked(rail)),
          );
        },
      ),
    ],
    if (view.problem case final problem?) ...[
      const Gap(16.0),
      BullText(
        fundReadProblemMessage(
          context,
          problem,
          otherwise: context.loc.fundExchangeErrorFetchingBankCodes,
        ),
        style: context.bullType.body,
        color: Theme.of(context).colorScheme.error,
        textAlign: TextAlign.center,
      ),
      const Gap(8.0),
      BullButton.secondary(
        label: context.loc.retry,
        onPressed: () => onEvent(const FundRetryPressed()),
      ),
    ],
  ];
}
