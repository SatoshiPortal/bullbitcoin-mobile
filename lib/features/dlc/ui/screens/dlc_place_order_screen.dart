import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/place_order/dlc_place_order_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DlcPlaceOrderScreen extends StatefulWidget {
  const DlcPlaceOrderScreen({super.key, this.instrumentId});

  final String? instrumentId;

  @override
  State<DlcPlaceOrderScreen> createState() => _DlcPlaceOrderScreenState();
}

class _DlcPlaceOrderScreenState extends State<DlcPlaceOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instrumentController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    if (widget.instrumentId != null) {
      _instrumentController.text = widget.instrumentId!;
      context.read<DlcPlaceOrderCubit>().setInstrument(widget.instrumentId!);
    }
  }

  @override
  void dispose() {
    _instrumentController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<DlcPlaceOrderCubit>().submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place DLC Order')),
      body: BlocConsumer<DlcPlaceOrderCubit, DlcPlaceOrderState>(
        listener: (context, state) {
          if (state.isSuccess) {
            final orderId = state.submittedOrderResponse?['order_id'];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  orderId != null
                      ? 'Order placed! ID: ${orderId.toString().substring(0, orderId.toString().length.clamp(0, 8))}…'
                      : 'Order placed successfully!',
                ),
                backgroundColor: Colors.green,
              ),
            );
            context.read<DlcPlaceOrderCubit>().reset();
            _priceController.clear();
            _quantityController.text = '1';
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
                  // ── Instrument ID ─────────────────────────────────────────
                  _SectionLabel(label: 'Instrument ID'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _instrumentController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. btc-usd-call-50000-2024-12',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                    onChanged: (v) =>
                        context.read<DlcPlaceOrderCubit>().setInstrument(v),
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

                  // ── Price ─────────────────────────────────────────────────
                  _SectionLabel(label: 'Price (sats)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
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
                      if (n != null) context.read<DlcPlaceOrderCubit>().setPrice(n);
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
                      if (n != null) context.read<DlcPlaceOrderCubit>().setQuantity(n);
                    },
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
