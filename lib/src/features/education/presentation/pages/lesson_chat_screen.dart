// lib/src/features/education/presentation/pages/lesson_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ai_status/presentation/widgets/chat_interface.dart';
import '../../../ai_status/presentation/widgets/voice_to_voice_widget.dart';
import '../../../../../services/ai_edge_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/lesson_recording_service.dart';

class LessonChatScreen extends ConsumerStatefulWidget {
  final String lessonId;
  
  const LessonChatScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonChatScreen> createState() => _LessonChatScreenState();
}

class _LessonChatScreenState extends ConsumerState<LessonChatScreen> with SingleTickerProviderStateMixin {
  final _logger = FeatureLogger('LessonChatScreen');
  late TabController _tabController;
  
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _responseScrollController = ScrollController();
  final _lessonService = LessonRecordingService();
  
  String _response = '';
  bool _isLoading = false;
  bool _isModelReady = false;
  RecordedLesson? _lesson;
  String _lessonContext = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLesson();
    _checkModelStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _responseScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() async {
    try {
      await _lessonService.initialize();
      final lesson = _lessonService.getLessonById(widget.lessonId);
      
      if (lesson != null) {
        setState(() {
          _lesson = lesson;
          _lessonContext = _buildLessonContext(lesson);
          _response = 'I\'m ready to discuss your lesson "${lesson.title}". '
                    'I have access to your ${lesson.transcript != null ? 'transcript and ' : ''}'
                    'lesson content. What would you like to explore?';
        });
        _logger.i('Loaded lesson: ${lesson.title}');
      } else {
        setState(() {
          _response = 'Lesson not found. Please check the lesson ID and try again.';
        });
        _logger.w('Lesson not found: ${widget.lessonId}');
      }
    } catch (e) {
      _logger.e('Error loading lesson', error: e);
      setState(() {
        _response = 'Error loading lesson content. Please try again.';
      });
    }
  }

  String _buildLessonContext(RecordedLesson lesson) {
    final context = StringBuffer();
    context.writeln('LESSON CONTEXT:');
    context.writeln('Title: ${lesson.title}');
    context.writeln('Category: ${lesson.category}');
    context.writeln('Duration: ${_formatDuration(lesson.duration)}');
    context.writeln('Date: ${lesson.dateRecorded}');
    
    if (lesson.transcript != null && lesson.transcript!.isNotEmpty) {
      context.writeln('\nTRANSCRIPT:');
      context.writeln(lesson.transcript!);
    }
    
    if (lesson.summary != null && lesson.summary!.isNotEmpty) {
      context.writeln('\nSUMMARY:');
      context.writeln(lesson.summary!);
    }
    
    context.writeln('\n---\nAs an AI tutor, provide helpful insights and answer questions about this lesson content.');
    
    return context.toString();
  }

  Future<void> _checkModelStatus() async {
    try {
      final systemInfo = await AIEdgeService.getSystemInfo();
      setState(() {
        _isModelReady = systemInfo['isInitialized'] ?? false;
      });
    } catch (e) {
      _logger.e('Error checking model status', error: e);
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
      _response = 'GemmaTutor is analyzing your lesson and preparing a response...';
    });

    try {
      // Include lesson context in the prompt
      final contextualPrompt = '$_lessonContext\n\nSTUDENT QUESTION: $prompt\n\nPlease provide a helpful educational response based on the lesson content above.';
      
      final result = await AIEdgeService.generateText(contextualPrompt);

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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson?.title ?? 'Lesson Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/history');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showLessonInfo,
            tooltip: 'Lesson Information',
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
            // Lesson context indicator
            if (_lesson != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.school,
                      color: Colors.blue[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Discussing lesson: ${_lesson!.title} (${_lesson!.category})',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
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
          // Lesson-specific tips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Lesson-Based Learning',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Ask questions about specific parts of your lesson'),
                const Text('• Request clarification on concepts you recorded'),
                const Text('• Get suggestions for improving your teaching'),
                const Text('• Explore related topics and examples'),
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
              hintText: 'Ask about your lesson content...',
              buttonText: 'Ask About This Lesson',
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
                      'Voice Discussion',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Discuss your lesson content naturally'),
                const Text('• Ask follow-up questions about what you taught'),
                const Text('• Get spoken feedback and suggestions'),
                const Text('• Perfect for reflective learning'),
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

  void _showLessonInfo() {
    if (_lesson == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_lesson!.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Category', _lesson!.category),
            _buildInfoRow('Duration', _formatDuration(_lesson!.duration)),
            _buildInfoRow('Date', '${_lesson!.dateRecorded.day}/${_lesson!.dateRecorded.month}/${_lesson!.dateRecorded.year}'),
            if (_lesson!.transcript != null && _lesson!.transcript!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Transcript Available',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${_lesson!.transcript!.length} characters',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_lesson!.summary != null && _lesson!.summary!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'AI Summary',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _lesson!.summary!,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}