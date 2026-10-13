import 'package:bb_mobile/core/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter/material.dart';

String describePsbtPolicyNode(
  BuildContext context,
  BitcoinPolicyNode node,
  Wallet wallet,
) => describeBitcoinPolicyNode(
  context,
  node,
  wallet,
  summarizeConjunctions: true,
);
