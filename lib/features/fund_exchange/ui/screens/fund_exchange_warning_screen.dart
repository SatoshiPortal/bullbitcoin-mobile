import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FundExchangeWarningScreen extends StatelessWidget {
  const FundExchangeWarningScreen({super.key, required this.fundingMethod});

  final FundingMethod fundingMethod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasConfirmedNoCoercion = context.select(
      (FundExchangeBloc bloc) => bloc.state.hasConfirmedNoCoercion,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Funding')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // or start, end, etc.
            children: [
              const Gap(24.0),
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.tertiary,
                child: Icon(
                  Icons.shield_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Gap(8.0),
              BBText(
                'Watch out for scammers',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(8.0),
              BBText(
                'If someone is asking you to buy Bitcoin or "helping you", be careful, they may be trying to scam you!',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const Gap(24.0),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        'Common scammer tactics',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const Gap(8.0),
                      ..._tactics.map(
                        (tactic) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  tactic,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(24.0),
              CheckboxListTile(
                tileColor: theme.colorScheme.secondaryFixedDim,
                contentPadding: const EdgeInsets.all(8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                value: hasConfirmedNoCoercion,
                onChanged: (value) {
                  context.read<FundExchangeBloc>().add(
                    FundExchangeEvent.noCoercionConfirmed(value ?? false),
                  );
                },
                title: BBText(
                  'I confirm that I am not being asked asked to buy Bitcoin by someone else.',
                  style: theme.textTheme.bodyLarge,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BBButton.big(
            label: 'Continue',
            disabled: !hasConfirmedNoCoercion,
            onPressed: () {
              // To not go back to the warning but directly go to payment method selection
              // screen we use `pushReplacementNamed` instead of `pushNamed` here.
              switch (fundingMethod) {
                case FundingMethod.emailETransfer:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeEmailETransfer.name,
                  );
                case FundingMethod.bankTransferWire:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeBankTransferWire.name,
                  );
                case FundingMethod.onlineBillPayment:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeOnlineBillPayment.name,
                  );
                case FundingMethod.canadaPost:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeCanadaPost.name,
                  );
                case FundingMethod.sepaTransfer:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeSepaTransfer.name,
                  );
                case FundingMethod.speiTransfer:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeSpeiTransfer.name,
                  );
                case FundingMethod.crIbanCrc:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeCostaRicaIbanCrc.name,
                  );
                case FundingMethod.crIbanUsd:
                  context.pushReplacementNamed(
                    FundExchangeRoute.fundExchangeCostaRicaIbanUsd.name,
                  );
              }
            },
            bgColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  List<String> get _tactics => const [
    'They are promising returns on investment',
    'They are offering you a loan',
    'They say they work for debt or tax collection',
    'They ask to send Bitcoin to their address',
    'They ask to send Bitcoin on another platform',
    'They want you to share your screen',
    'They tell you not to worry about this warning',
    'They are pressuring you to act quickly',
  ];
}
