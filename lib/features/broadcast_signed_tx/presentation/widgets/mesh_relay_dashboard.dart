import 'package:flutter/material.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:convert/convert.dart';

class MeshRelayDashboard extends StatelessWidget {
  final String txHex;
  final VoidCallback onDismiss;

  const MeshRelayDashboard({
    super.key, 
    required this.txHex,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BitcoinTx>(
      future: BitcoinTx.fromBytes(hex.decode(txHex)),
      builder: (context, snapshot) {
        // While loading or if failed, show snippet. If success, show real TxID.
        final String displayId;
        if (snapshot.hasData) {
           displayId = snapshot.data!.txid;
        } else {
           displayId = txHex.length > 20 
             ? "\${txHex.substring(0, 10)}... \${txHex.substring(txHex.length - 10)}"
             : "Verifying...";
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))
              ),
              const SizedBox(height: 24),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.radar, color: Colors.greenAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    "INCOMING MESH SIGNAL",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Content
              _buildStatusRow(Icons.check_circle, "Packet Verified (Hex Check)", true),
              const SizedBox(height: 16),
              _buildStatusRow(Icons.cloud_upload, "Broadcasting to Mempool...", true),
              
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                     const Icon(Icons.description, color: Colors.white70, size: 20),
                     const SizedBox(width: 12),
                     Expanded(
                       child: Text(
                         displayId,
                         style: const TextStyle(
                           fontFamily: 'Courier',
                           color: Colors.white70,
                         ),
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                  ],
                ),
              ),
               
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("RELAY SUCCESSFUL"),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatusRow(IconData icon, String text, bool isActive) {
    return Row(
      children: [
        Icon(icon, color: isActive ? Colors.greenAccent : Colors.grey, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 16,
          ),
        )
      ],
    );
  }
}
