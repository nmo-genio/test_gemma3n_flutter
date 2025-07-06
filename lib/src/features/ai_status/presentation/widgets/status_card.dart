// lib/src/features/ai_status/widgets/status_card.dart
import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String status;
  final bool isLoading;
  final double downloadProgress;

  const StatusCard({
    super.key,
    required this.status,
    required this.isLoading,
    required this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Gemma 3n Status',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(status),
            if (isLoading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: downloadProgress > 0 ? downloadProgress : null,
              ),
              if (downloadProgress > 0)
                Text('${(downloadProgress * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
      ),
    );
  }
}