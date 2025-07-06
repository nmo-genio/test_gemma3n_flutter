// lib/src/features/ai_status/widgets/system_info_card.dart
import 'package:flutter/material.dart';

class SystemInfoCard extends StatelessWidget {
  final Map<String, dynamic> systemInfo;

  const SystemInfoCard({
    super.key,
    required this.systemInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (systemInfo.isEmpty) return const SizedBox.shrink();

    final deviceInfo = systemInfo['deviceInfo'] as Map<String, dynamic>? ?? {};
    final modelInfo = systemInfo['modelInfo'] as Map<String, dynamic>? ?? {};
    final capabilities = systemInfo['capabilities'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'System Information',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Device info
            Text('Device: ${deviceInfo['manufacturer'] ?? 'Unknown'} ${deviceInfo['model'] ?? 'Device'}'),
            Text('Android: ${deviceInfo['androidVersion'] ?? 'Unknown'} (API ${deviceInfo['apiLevel'] ?? 'Unknown'})'),
            Text('Arch: ${deviceInfo['cpuArchitecture'] ?? 'Unknown'}'),

            if (modelInfo.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text('Model: ${modelInfo['modelType'] ?? 'Gemma 3n E4B'}'),
              Text('Size: ${(modelInfo['modelSizeMB'] ?? 997).toStringAsFixed(1)} MB'),
              Text('Threads: ${modelInfo['numThreads'] ?? 4}'),
            ],

            if (capabilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text('Capabilities:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              _buildCapabilityRow('GPU Support', capabilities['hasGPU'] ?? false),
              _buildCapabilityRow('FP16 Support', capabilities['supportsFP16'] ?? false),
              _buildCapabilityRow('INT8 Support', capabilities['supportsINT8'] ?? true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityRow(String label, bool supported) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            supported ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: supported ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}