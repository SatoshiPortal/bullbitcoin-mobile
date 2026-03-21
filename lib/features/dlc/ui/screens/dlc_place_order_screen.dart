import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/place_order/dlc_place_order_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Temporary stub values — will be replaced by real wallet key integration.
const _stubPubkey = 'stub_pubkey';
const _stubSignedOfferHex = 'stub_signed_offer_hex';

class DlcPlaceOrderScreen extends StatefulWidget {
  const DlcPlaceOrderScreen({super.key});

  @override
  State<DlcPlaceOrderScreen> createState() => _DlcPlaceOrderScreenState();
}

class _DlcPlaceOrderScreenState extends State<DlcPlaceOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _strikePriceController = TextEditingController();
  final _premiumController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  DateTime? _selectedExpiry;

  @override
  void dispose() {
    _strikePriceController.dispose();
    _premiumController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;
    final expiry = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
    setState(() => _selectedExpiry = expiry);
    context.read<DlcPlaceOrderCubit>().setExpiry(expiry);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date')),
      );
      return;
    }
    context.read<DlcPlaceOrderCubit>().submit(
          makerPubkey: _stubPubkey,
          signedOfferHex: _stubSignedOfferHex,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place DLC Order')),
      body: BlocConsumer<DlcPlaceOrderCubit, DlcPlaceOrderState>(
        listener: (context, state) {
          if (state.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order placed! ID: ${state.submittedOrder!.id.substring(0, 8)}…',
                ),
                backgroundColor: Colors.green,
              ),
            );
            context.read<DlcPlaceOrderCubit>().reset();
            _strikePriceController.clear();
            _premiumController.clear();
            _quantityController.text = '1';
            setState(() => _selectedExpiry = null);
          }
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.error}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Option Type ──────────────────────────────────────────
                  _SectionLabel(label: 'Option Type'),
                  const SizedBox(height: 8),
                  SegmentedButton<DlcOptionType>(
                    segments: const [
                      ButtonSegment(
                        value: DlcOptionType.call,
                        label: Text('Call'),
                        icon: Icon(Icons.trending_up),
                      ),
                      ButtonSegment(
                        value: DlcOptionType.put,
                        label: Text('Put'),
                        icon: Icon(Icons.trending_down),
                      ),
                    ],
                    selected: {state.optionType},
                    onSelectionChanged: (selection) => context
                        .read<DlcPlaceOrderCubit>()
                        .setOptionType(selection.first),
                  ),
                  const SizedBox(height: 20),

                  // ── Side ─────────────────────────────────────────────────
                  _SectionLabel(label: 'Side'),
                  const SizedBox(height: 8),
                  SegmentedButton<DlcOrderSide>(
                    segments: const [
                      ButtonSegment(
                        value: DlcOrderSide.buy,
                        label: Text('Buy'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                      ButtonSegment(
                        value: DlcOrderSide.sell,
                        label: Text('Sell'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                    ],
                    selected: {state.side},
                    onSelectionChanged: (selection) => context
                        .read<DlcPlaceOrderCubit>()
                        .setSide(selection.first),
                  ),
                  const SizedBox(height: 20),

                  // ── Strike Price ─────────────────────────────────────────
                  _SectionLabel(label: 'Strike Price (sats)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _strikePriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'e.g. 5000000',
                      suffixText: 'sats',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a positive amount';
                      return null;
                    },
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) {
                        context.read<DlcPlaceOrderCubit>().setStrikePrice(n);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Premium ──────────────────────────────────────────────
                  _SectionLabel(label: 'Premium per Contract (sats)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _premiumController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'e.g. 10000',
                      suffixText: 'sats',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a positive amount';
                      return null;
                    },
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) {
                        context.read<DlcPlaceOrderCubit>().setPremium(n);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Quantity ─────────────────────────────────────────────
                  _SectionLabel(label: 'Quantity (contracts)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'e.g. 1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter at least 1';
                      return null;
                    },
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) {
                        context.read<DlcPlaceOrderCubit>().setQuantity(n);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Expiry ───────────────────────────────────────────────
                  _SectionLabel(label: 'Expiry'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickExpiry,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedExpiry == null
                          ? 'Select expiry date & time'
                          : '${_selectedExpiry!.toLocal()}'.substring(0, 16),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Submit ───────────────────────────────────────────────
                  FilledButton(
                    onPressed: state.isSubmitting ? null : _submit,
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Place Order'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
