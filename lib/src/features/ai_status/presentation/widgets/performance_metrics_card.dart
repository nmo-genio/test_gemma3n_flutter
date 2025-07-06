// lib/src/features/ai_status/widgets/performance_metrics_card.dart
import 'package:flutter/material.dart';

class PerformanceMetricsCard extends StatelessWidget {
  final Map<String, dynamic> performanceMetrics;

  const PerformanceMetricsCard({
    super.key,
    required this.performanceMetrics,
  });

  @override
  Widget build(BuildContext context) {
    if (performanceMetrics.isEmpty) return const SizedBox.shrink();

    final avgInferenceTime = performanceMetrics['avgInferenceTimeMs'] ?? 0;
    final avgTokensPerSecond = performanceMetrics['avgTokensPerSecond'] ?? 0;
    final totalInferences = performanceMetrics['totalInferences'] ?? 0;
    final preferredUnit = performanceMetrics['preferredProcessingUnit'] ?? 'CPU';
    final batteryOptimized = performanceMetrics['batteryOptimized'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Performance stats in grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildMetricTile(
                  context,
                  'Avg Inference',
                  '${avgInferenceTime}ms',
                  Icons.timer,
                  Colors.blue,
                ),
                _buildMetricTile(
                  context,
                  'Tokens/sec',
                  '$avgTokensPerSecond',
                  Icons.speed,
                  Colors.green,
                ),
                _buildMetricTile(
                  context,
                  'Total Runs',
                  '$totalInferences',
                  Icons.analytics,
                  Colors.orange,
                ),
                _buildMetricTile(
                  context,
                  'Preferred Unit',
                  preferredUnit,
                  preferredUnit == 'GPU' ? Icons.videogame_asset : Icons.memory,
                  preferredUnit == 'GPU' ? Colors.green : Colors.blue,
                ),
              ],
            ),

            if (batteryOptimized) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.battery_saver, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Battery optimization enabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}