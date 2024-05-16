import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InformationPage extends StatelessWidget {
  const InformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: BBAppBar(
          text: 'Information',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Title(text: 'What is the Instant Payments Wallet?'),
            Paragraph(
              text:
                  'The funds in the Instant Payment Wallet are not “real” Bitcoin. They are Liquid Network Bitcoin (L-BTC), a Bitcoin-backed token which exists on a separate ledger called a “sidechain”. Each Liquid Bitcoin is backed 1:1 by real Bitcoin using a transparent peg mechanism maintained by a federation of 15 companies. The Bitcoin reserves held by the Liquid Federation are fully auditable, and anybody can verify that every Liquid Bitcoin is backed by a real Bitcoin.',
            ),
            Paragraph(
              text:
                  'Liquid Network payments are faster, cheaper and more private than regular Bitcoin payments. You have full self-custody of the Liquid Bitcoin assets in the Instant Payments Wallet and you don’t need any permission from anyone to send and receive payments. You are fully and exclusively responsible for securing access to your wallet backup, without which nobody can restore access to your Liquid Bitcoin assets.',
            ),
            Paragraph(
              text:
                  'Keeping money on the Liquid Network is much safer using a traditional custodial wallet or an exchange.',
            ),
            Paragraph(
              text:
                  'However, holding your money as Liquid Bitcoin in the Instant Bitcoin Payments wallet is far less secure than holding it as real Bitcoin in the Secure Bitcoin Wallet. The real-world value of the L-BTC depends on your ability to redeem them for real Bitcoin, which in turn depends on swap providers that are members of the Liquid Network, which in turn depends on the Liquid Network federation never being compromised or shut down.In other words, in the unlikely event that Liquid Network federation members become unable or unwilling to redeem your Liquid Bitcoin for real Bitcoin, the value of L-BTC tokens would become worthless.',
            ),
            Paragraph(
              text:
                  'For this reason, we recommend that you only keep small amounts in the Instant Payments Wallet and that you keep your savings in the Secure Bitcoin Wallet, or in an imported hardware wallet. ',
            ),
            Title(text: 'What is the Instant Payments Wallet?'),
            Paragraph(
              text:
                  'Every time you receive a Lightning Network payment with the Instant Payment Wallet, the sender’s funds are actually received by a 3rd party swap provider, converted to Liquid Bitcoin and sent to your wallet.',
            ),
            Paragraph(
              text:
                  'Every time you send a Lightning Network payment with this wallet, you are actually sending a Liquid Bitcoin payment to a 3rd party swap provider which converts them to real Bitcoin on the Lightning Network and sends a Lightning Network payment to the recipient.',
            ),
            Paragraph(
              text:
                  'These swaps are fully non-custodial and trustless, meaning that there is no way for the swap provider to steal your funds. Bull Bitcoin is not involved in making those swap transactions and does not require or store any personal information.',
            ),
            Title(text: 'What should I do with this wallet?'),
            Paragraph(
              text:
                  'The Instant Payments Wallet is designed for you to be able to receive Bitcoin payments (or buying Bitcoin) and send Bitcoin payments (or sell Bitcoin) on a day-to-day basis without paying Bitcoin network fees.',
            ),
            Paragraph(
              text:
                  'If you are a merchant or you are accumulating Bitcoin, use this wallet to receive payments below 0.01 BTC and, once you have accumulated over 0.01 BTC, transfer those Bitcoins to the secure Bitcoin wallet or any other self-custodial Bitcoin wallet.',
            ),
            Paragraph(
              text:
                  'If you want to spend your Bitcoin, transfer a small amount in the Instant Payment Wallet and use it to pay for your expenses. When you run out of funds in the Instant Payments Wallet, simply refill it.',
            ),
            Title(
              text:
                  'How do I fund or withdraw L-BTC from the Instant Bitcoin Wallet?',
            ),
            Paragraph(
              text:
                  'To fund the wallet with “real” Bitcoin, click “Receive” and select “Lightning Network”. To withdraw L-BTC, click “Send” and simply paste a "Lighting Invoice”.',
            ),
            Title(
              text:
                  'Can I move funds between the Instant Payments Wallet and the Secure Bitcoin Wallet directly?',
            ),
            Paragraph(
              text:
                  'In the next major update of the app, you will be able to transfer funds in between the two wallets directly. For the moment, this feature is not enabled and you first have to send the funds to an external Lightning network wallet.',
            ),
            Title(
              text: 'How does the backup work?',
            ),
            Paragraph(
              text:
                  'The Instant Bitcoin Wallet uses the same backup seed words as the Secure Bitcoin Wallet. You only need one backup for both wallets.',
            ),
            Title(
              text:
                  'Should I use the Instant Payments wallet instead of a non-custodial Lightning Network Wallet?',
            ),
            Paragraph(
              text:
                  'Using a non-custodial Lightning network wallet such as Phoenix Wallet will give you a higher degree of security. However, because you will have to deal with Lightning Network channel management, it may be less convenient and harder to use. Because Lightning channels require on-chain transactions to be opened and close, and because you will likely need to pay a fee to Lightning service providers, it may be more expensive to use a non-custodial lightning wallet. ',
            ),
            Title(
              text: 'What are the transaction fees?',
            ),
            Paragraph(
              text:
                  'Each payment in and out of the Instant Payments Wallet implies two Liquid Network transactions. These are typically very small and should be around 0.00000050 BTC (50 sats). If you are receiving or sending Lightning Network payments with the Secure Bitcoin Wallet, you will have to pay for two on-chain Bitcoin transactions every payment, which can be quite expensive. ',
            ),
            Paragraph(
              text:
                  'In addition, the swap provider may also charge swap fees. At the moment, the swap provider (Boltz) charges the following fees:',
            ),
            Paragraph(
              text:
                  ' - Receiving Lightning Network payments in the Instant Payment Wallet: 0.25%',
            ),
            Paragraph(
              text:
                  ' - Sending Lightning Network payments from the Instant Payment Wallet: 0.1%',
            ),
            Paragraph(
              text:
                  ' - Receiving Lightning Network payments in the Secure Bitcoin Wallet: 0.5%',
            ),
            Paragraph(
              text:
                  ' - Sending Lightning Network payments from the Secure Bitcoin Wallet: 0.1%',
            ),
          ],
        ),
      ),
    );
  }
}

class Title extends StatelessWidget {
  const Title({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: BBText.titleLarge(
        text,
        isBold: true,
      ),
    );
  }
}

class Paragraph extends StatelessWidget {
  const Paragraph({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: BBText.bodySmall(
        text,
      ),
    );
  }
}
