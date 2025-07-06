//lib/src/features/ai_status/widgets/memory_usage_card.dart
import 'package:flutter/material.dart';

class MemoryUsageCard extends StatelessWidget {
  final Map<String, dynamic> memoryUsage;

  const MemoryUsageCard({
    super.key,
    required this.memoryUsage,
  });

@override
  Widget build(BuildContext context) {
    if (memoryUsage.isEmpty) return const SizedBox.shrink();

    final totalMB = (memoryUsage['totalMB'] ?? 0).toDouble();
    final usedMB = (memoryUsage['usedMB'] ?? 0).toDouble();
    final availableMB = (memoryUsage['availableMB'] ?? 0).toDouble();
    final modelSizeMB = (memoryUsage['modelSizeMB'] ?? 0).toDouble();
    final isUnder3GB = usedMB < 3072;

    // GPU memory info
    final gpuTotalMB = (memoryUsage['gpuTotalMB'] ?? 0).toDouble();
    final gpuUsedMB = (memoryUsage['gpuUsedMB'] ?? 0).toDouble();
    final hasGPUMemory = gpuTotalMB > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory,
                  color: isUnder3GB ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Memory Usage',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main memory
            Text('System Memory:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            _buildMemoryBar(context, 'RAM', usedMB, totalMB, Colors.blue),
            const SizedBox(height: 8),

            Text('Total: ${totalMB.toStringAsFixed(0)} MB'),
            Text('Used: ${usedMB.toStringAsFixed(0)} MB'),
            Text('Available: ${availableMB.toStringAsFixed(0)} MB'),
            Text('Model: ${modelSizeMB.toStringAsFixed(0)} MB'),

            // GPU memory (if available)
            if (hasGPUMemory) ...[
              const SizedBox(height: 12),
              const Divider(),
              Text('GPU Memory:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _buildMemoryBar(context, 'GPU', gpuUsedMB, gpuTotalMB, Colors.green),
              const SizedBox(height: 8),
              Text('GPU Total: ${gpuTotalMB.toStringAsFixed(0)} MB'),
              Text('GPU Used: ${gpuUsedMB.toStringAsFixed(0)} MB'),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isUnder3GB ? Icons.check_circle : Icons.warning,
                  color: isUnder3GB ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isUnder3GB ? 'Memory usage under 3GB ✓' : 'Memory usage: ${usedMB.toStringAsFixed(0)}MB',
                  style: TextStyle(
                    color: isUnder3GB ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
}

Widget _buildMemoryBar(BuildContext context, String label, double used, double total, Color color) {
    final percentage = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${(percentage * 100).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
}
}