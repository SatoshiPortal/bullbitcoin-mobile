import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: TopBar(
          title: 'Transactions',
          onBack: () {
            context.pop();
          },
        ),
        backgroundColor: context.colour.onPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FilterRow(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                const Gap(16.0),
                BBText(
                  'Today',
                  style: context.font.bodyLarge?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
                const Gap(8.0),
                const TxItem(
                  icon: Icons.arrow_downward,
                  amount: '0.00162199 BTC',
                  label: 'Label',
                  date: 'Jan 03',
                  walletType: 'Onchain',
                  walletColor: Colors.orange,
                ),
                const TxItem(
                  icon: Icons.arrow_downward,
                  amount: '0.00162199 BTC',
                  label: 'Label',
                  date: 'Jan 03',
                  walletType: 'Liquid',
                  walletColor: Colors.yellow,
                ),
                const TxItem(
                  icon: Icons.swap_horiz,
                  amount: '0.00162199 BTC',
                  label: 'Label',
                  date: 'Jan 03',
                  walletType: 'Instant',
                  walletColor: Colors.amber,
                ),
                const Gap(16.0),
                BBText(
                  'March 2025',
                  style: context.font.bodyLarge?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
                const Gap(8.0),
                const TxItem(
                  icon: Icons.arrow_downward,
                  amount: '0.00162199 BTC',
                  label: 'Label',
                  date: 'Jan 03',
                  walletType: 'Onchain',
                  walletColor: Colors.orange,
                ),
                const TxItem(
                  icon: Icons.arrow_downward,
                  amount: '0.00162199 BTC',
                  label: 'Label',
                  date: 'Jan 03',
                  walletType: 'Liquid',
                  walletColor: Colors.yellow,
                ),
                const TxItem(
                  icon: Icons.swap_horiz,
                  amount: '0.00162199 BTC',
                  label: 'Label',
                  date: 'Jan 03',
                  walletType: 'Instant',
                  walletColor: Colors.amber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FilterRow extends StatefulWidget {
  const FilterRow({super.key});

  @override
  State<FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<FilterRow> {
  final List<String> filters = const [
    'All',
    'Send',
    'Receive',
    'Swap',
    'Sell',
    'Pay',
  ];
  String selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: filters.map((filter) {
          final isSelected = filter == selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterItem(
              title: filter,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterItem extends StatelessWidget {
  const FilterItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? context.colour.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(2.0),
          border: Border.all(
            color: isSelected
                ? context.colour.secondaryFixedDim
                : context.colour.outline,
          ),
        ),
        child: BBText(
          title,
          style: context.font.bodyMedium?.copyWith(
            color: isSelected
                ? context.colour.onSecondary
                : context.colour.secondary,
          ),
        ),
      ),
    );
  }
}

class TxItem extends StatelessWidget {
  const TxItem({
    super.key,
    required this.icon,
    required this.amount,
    this.label,
    required this.date,
    required this.walletType,
    required this.walletColor,
  });

  final IconData icon;
  final String amount;
  final String? label;
  final String date;
  final String walletType;
  final Color walletColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(2.0),
        boxShadow: const [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              border: Border.all(
                color: context.colour.surface,
              ),
              borderRadius: BorderRadius.circular(2.0),
            ),
            child: Icon(icon, color: context.colour.secondary),
          ),
          const Gap(16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  amount,
                  style: context.font.bodyLarge,
                ),
                if (label != null)
                  BBText(
                    label!,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: walletColor,
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: BBText(
                  walletType,
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.secondary,
                  ),
                ),
              ),
              const Gap(4.0),
              Row(
                children: [
                  BBText(
                    date,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
                  const Gap(4.0),
                  Icon(
                    Icons.check_circle,
                    size: 12.0,
                    color: context.colour.inverseSurface,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
