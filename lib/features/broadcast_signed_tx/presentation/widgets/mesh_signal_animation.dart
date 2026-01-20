import 'package:flutter/material.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/core/mesh/mesh_service.dart';

class MeshSignalAnimation extends StatefulWidget {
  final bool isLockedOn;

  const MeshSignalAnimation({super.key, this.isLockedOn = false});

  @override
  State<MeshSignalAnimation> createState() => _MeshSignalAnimationState();
}

class _MeshSignalAnimationState extends State<MeshSignalAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }
  
  @override
  void didUpdateWidget(MeshSignalAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLockedOn != oldWidget.isLockedOn) {
      if (widget.isLockedOn) {
        // Fast pulse for excitement!
        _controller.duration = const Duration(milliseconds: 500); 
        _controller.repeat();
      } else {
        // Slow search
        _controller.duration = const Duration(seconds: 2);
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Colors: Orange for searching, Green for Locked-on
    final color = widget.isLockedOn ? Colors.greenAccent : Colors.orangeAccent;
    final meshService = locator<MeshService>();
    
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dynamic Ripple/Pulse
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 200 * (widget.isLockedOn ? 1.0 : _controller.value), // Lock size or ripple
                height: 200 * (widget.isLockedOn ? 1.0 : _controller.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: color.withOpacity(1.0 - _controller.value),
                      width: 10 * (1.0 - _controller.value)),
                ),
              );
            },
          ),
          
          // Progress Ring (Visible when sending chunks)
          ValueListenableBuilder<double>(
            valueListenable: meshService.uploadProgressNotifier,
            builder: (context, progress, child) {
              if (progress <= 0.0 || progress >= 1.0) return const SizedBox.shrink();
              return SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  color: Colors.blueAccent, // Blue for "Data Transfer"
                  backgroundColor: Colors.transparent,
                ),
              );
            },
          ),
          
          // Core Icon
          Icon(
            widget.isLockedOn ? Icons.check_circle : Icons.wifi_tethering,
            size: 64,
            color: color,
          ),
          
          // Text Status
          Positioned(
             bottom: 20,
             child: ValueListenableBuilder<double>(
               valueListenable: meshService.uploadProgressNotifier,
               builder: (context, progress, child) {
                 String text = widget.isLockedOn ? "RELAY FOUND!" : "SEARCHING...";
                 if (progress > 0 && progress < 1.0) {
                    text = "SENDING ${(progress * 100).toInt()}%...";
                 }
                 
                 return Text(
                    text,
                    style: TextStyle(
                       color: color, 
                       fontWeight: FontWeight.bold,
                       letterSpacing: 1.5
                    ),
                 );
               }
             )
          )
        ],
      ),
    );
  }
}
