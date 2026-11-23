import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/ride_recording_controller.dart';

/// Bedienfeld zum Starten, Pausieren und Beenden einer Fahrt.
class RideRecordingPanel extends StatefulWidget {
  const RideRecordingPanel({super.key, required this.controller});

  final RideRecordingController controller;

  @override
  State<RideRecordingPanel> createState() => _RideRecordingPanelState();
}

class _RideRecordingPanelState extends State<RideRecordingPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.state == RideRecordingState.recording) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant RideRecordingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _stop() async {
    final ride = await widget.controller.stop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ride == null
              ? 'Keine GPS-Punkte aufgezeichnet. Fahrt wurde verworfen.'
              : 'Fahrt gespeichert: ${ride.formattedDistance}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.state;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  state == RideRecordingState.recording
                      ? Icons.fiber_manual_record
                      : state == RideRecordingState.paused
                          ? Icons.pause_circle
                          : Icons.route,
                  color: state == RideRecordingState.recording
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state == RideRecordingState.recording
                        ? 'Fahrt wird aufgezeichnet'
                        : state == RideRecordingState.paused
                            ? 'Aufzeichnung pausiert'
                            : 'Fahrt aufzeichnen',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (state != RideRecordingState.idle) ...[
                  Text(
                    '${(controller.distanceMeters / 1000).toStringAsFixed(2)} km',
                    key: const Key('ride_distance'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDuration(controller.duration),
                    key: const Key('ride_duration'),
                  ),
                ],
              ],
            ),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            if (state == RideRecordingState.idle)
              FilledButton.icon(
                key: const Key('start_ride_button'),
                onPressed: controller.start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Aufzeichnung starten'),
              )
            else if (state == RideRecordingState.recording)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('pause_ride_button'),
                      onPressed: controller.pause,
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('stop_ride_button'),
                      onPressed: _stop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Beenden'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('resume_ride_button'),
                      onPressed: controller.resume,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Fortsetzen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('stop_ride_button'),
                      onPressed: _stop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Beenden'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
