// lib/src/features/education/presentation/pages/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai_status/presentation/widgets/chat_interface.dart';
import '../../../ai_status/presentation/widgets/voice_to_voice_widget.dart';
import '../../../../../services/ai_edge_service.dart';
import '../../../../core/services/logger_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  final _logger = FeatureLogger('ChatScreen');
  late TabController _tabController;
  
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _responseScrollController = ScrollController();
  
  String _response = '';
  bool _isLoading = false;
  bool _isModelReady = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkModelStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _responseScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    try {
      final systemInfo = await AIEdgeService.getSystemInfo();
      setState(() {
        _isModelReady = systemInfo['isInitialized'] ?? false;
        if (_isModelReady) {
          _response = 'Hello! I\'m GemmaTutor, your AI learning companion. How can I help you learn today?';
        } else {
          _response = 'Gemma 3n model is not ready. Please initialize it from the AI Status page first.';
        }
      });
    } catch (e) {
      _logger.e('Error checking model status', error: e);
      setState(() {
        _response = 'Error checking AI model status. Please try again.';
      });
    }
  }

  Future<void> _generateText() async {
    if (!_isModelReady) {
      _showSnackBar('Please initialize the Gemma 3n model first', isError: true);
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showSnackBar('Please enter a question first', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _response = 'GemmaTutor is thinking...';
    });

    try {
      // Add educational context to the prompt
      final educationalPrompt = 'As GemmaTutor, an educational AI assistant, please help with this learning question: $prompt';
      
      final result = await AIEdgeService.generateText(educationalPrompt);

      if (result['success'] == true) {
        setState(() {
          _response = result['text'] ?? 'No response generated';
          _isLoading = false;
        });

        // Auto-scroll to show response
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_responseScrollController.hasClients) {
            _responseScrollController.animateTo(
              _responseScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        final inferenceTime = result['inferenceTimeMs'] ?? 0;
        final tokensPerSec = result['tokensPerSecond'] ?? 0;
        _showSnackBar('Response generated in ${inferenceTime}ms • $tokensPerSec tokens/sec');

      } else {
        setState(() {
          _response = 'Error: ${result['error']}';
          _isLoading = false;
        });
        _showSnackBar('Failed to generate response', isError: true);
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
      _showSnackBar('Unexpected error occurred', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with GemmaTutor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('Back button pressed in ChatScreen');
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkModelStatus,
            tooltip: 'Refresh model status',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/ai-status'),
            tooltip: 'AI Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.keyboard),
              text: 'Text Chat',
            ),
            Tab(
              icon: Icon(Icons.mic),
              text: 'Voice Chat',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Model status indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: _isModelReady 
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isModelReady ? Icons.check_circle : Icons.warning,
                    color: _isModelReady ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isModelReady 
                        ? 'GemmaTutor is ready to help you learn!'
                        : 'Model not ready - Please initialize from AI Status',
                    style: TextStyle(
                      color: _isModelReady ? Colors.green[700] : Colors.orange[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Text Chat Tab
                  _buildTextChatTab(),
                  
                  // Voice Chat Tab
                  _buildVoiceChatTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextChatTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Educational tips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Learning Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Ask specific questions about topics you want to learn'),
                const Text('• Request explanations, examples, or step-by-step guides'),
                const Text('• Ask for practice problems or quiz questions'),
                const Text('• Request summaries of complex topics'),
              ],
            ),
          ),

          // Chat interface
          Expanded(
            child: ChatInterface(
              promptController: _promptController,
              responseScrollController: _responseScrollController,
              response: _response,
              isLoading: _isLoading,
              onGenerate: _generateText,
              hintText: 'Ask GemmaTutor a learning question...',
              buttonText: 'Ask GemmaTutor',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceChatTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Voice instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.record_voice_over, color: Colors.purple[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Voice Learning',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Speak naturally and clearly'),
                const Text('• Ask questions as you would to a teacher'),
                const Text('• GemmaTutor will respond with spoken explanations'),
                const Text('• Perfect for hands-free learning'),
              ],
            ),
          ),

          // Voice interface
          Expanded(
            child: _isModelReady 
                ? const VoiceToVoiceWidget()
                : _buildModelNotReadyWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildModelNotReadyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber,
            size: 80,
            color: Colors.orange[400],
          ),
          const SizedBox(height: 16),
          Text(
            'AI Model Not Ready',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.orange[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please initialize the Gemma 3n model first',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.orange[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/ai-status'),
            icon: const Icon(Icons.settings),
            label: const Text('Go to AI Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}