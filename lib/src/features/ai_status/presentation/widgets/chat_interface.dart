// lib/src/features/ai_status/widgets/chat_interface.dart
import 'package:flutter/material.dart';

class ChatInterface extends StatelessWidget {
  final TextEditingController promptController;
  final ScrollController responseScrollController;
  final String response;
  final bool isLoading;
  final VoidCallback onGenerate;

  const ChatInterface({
    super.key,
    required this.promptController,
    required this.responseScrollController,
    required this.response,
    required this.isLoading,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Prompt input
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask Gemma 3n E4B',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: 'Enter your prompt...',
                    hintText: 'e.g., "Explain quantum computing", "Write a story about AI"',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  maxLines: 2, // Reduced from 3 to 2 lines
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onGenerate(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onGenerate,
                    icon: isLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send),
                    label: const Text('Generate with Gemma 3n'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Response area with responsive height
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate available height dynamically
            final screenHeight = MediaQuery.of(context).size.height;
            final maxHeight = (screenHeight * 0.3).clamp(200.0, 280.0); // 30% of screen, min 200, max 280

            return SizedBox(
              height: maxHeight,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gemma 3n Response',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SingleChildScrollView(
                            controller: responseScrollController,
                            child: SelectableText(
                              response.isEmpty
                                  ? 'Responses will appear here...'
                                  : response,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}