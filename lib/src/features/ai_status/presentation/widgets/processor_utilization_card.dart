// lib/src/features/ai_status/widgets/processor_utilization_card.dart
import 'package:flutter/material.dart';

class ProcessorUtilizationCard extends StatelessWidget {
  final Map<String, dynamic> processorInfo;

  const ProcessorUtilizationCard({
    super.key,
    required this.processorInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (processorInfo.isEmpty) return const SizedBox.shrink();

    final cpuUtilization = (processorInfo['cpuUtilization'] ?? 0.0).toDouble();
    final gpuUtilization = (processorInfo['gpuUtilization'] ?? 0.0).toDouble();
    final currentUnit = processorInfo['currentProcessingUnit'] ?? 'CPU';
    final isGPUAvailable = processorInfo['isGPUAvailable'] ?? false;
    final cpuCores = processorInfo['cpuCores'] ?? 4;
    final thermalState = processorInfo['thermalState'] ?? 'normal';
    final powerUsage = (processorInfo['powerUsageWatts'] ?? 0.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getProcessorIcon(currentUnit),
                  color: _getProcessorColor(currentUnit),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Processor Utilization',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getProcessorColor(currentUnit).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getProcessorColor(currentUnit)),
                  ),
                  child: Text(
                    currentUnit,
                    style: TextStyle(
                      color: _getProcessorColor(currentUnit),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CPU Utilization
            _buildUtilizationBar(
              context,
              'CPU',
              cpuUtilization,
              Icons.memory,
              Colors.blue,
              '$cpuCores cores',
            ),
            const SizedBox(height: 12),

            // GPU Utilization
            _buildUtilizationBar(
              context,
              'GPU',
              isGPUAvailable ? gpuUtilization : 0.0,
              Icons.videogame_asset,
              Colors.green,
              isGPUAvailable ? 'Available' : 'Not Available',
            ),
            const SizedBox(height: 16),

            // Additional metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    context,
                    'Thermal',
                    thermalState.toUpperCase(),
                    _getThermalIcon(thermalState),
                    _getThermalColor(thermalState),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricItem(
                    context,
                    'Power',
                    '${powerUsage.toStringAsFixed(1)}W',
                    Icons.battery_charging_full,
                    _getPowerColor(powerUsage),
                  ),
                ),
              ],
            ),

            if (processorInfo['cpuFrequencyMHz'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'CPU Frequency: ${processorInfo['cpuFrequencyMHz']} MHz',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUtilizationBar(
      BuildContext context,
      String label,
      double utilization,
      IconData icon,
      Color color,
      String subtitle,
      ) {
    final percentage = (utilization * 100).clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: utilization,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(
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
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProcessorIcon(String currentUnit) {
    switch (currentUnit.toUpperCase()) {
      case 'GPU':
        return Icons.videogame_asset;
      case 'CPU':
        return Icons.memory;
      default:
        return Icons.computer;
    }
  }

  Color _getProcessorColor(String currentUnit) {
    switch (currentUnit.toUpperCase()) {
      case 'GPU':
        return Colors.green;
      case 'CPU':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getThermalIcon(String thermalState) {
    switch (thermalState.toLowerCase()) {
      case 'hot':
        return Icons.warning;
      case 'warm':
        return Icons.thermostat;
      case 'normal':
      default:
        return Icons.check_circle;
    }
  }

  Color _getThermalColor(String thermalState) {
    switch (thermalState.toLowerCase()) {
      case 'hot':
        return Colors.red;
      case 'warm':
        return Colors.orange;
      case 'normal':
      default:
        return Colors.green;
    }
  }

  Color _getPowerColor(double powerUsage) {
    if (powerUsage > 5.0) return Colors.red;
    if (powerUsage > 2.0) return Colors.orange;
    return Colors.green;
  }
}