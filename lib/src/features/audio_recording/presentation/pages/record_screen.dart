// lib/src/features/audio_recording/presentation/pages/record_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:io';

import '../../../../core/services/lesson_recording_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../../services/ai_edge_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _logger = FeatureLogger('RecordScreen');
  final _lessonService = LessonRecordingService();
  final _voiceService = VoiceService();
  final _ttsService = TTSService();
  
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  Duration _recordingDuration = Duration.zero;
  String _currentTranscript = '';
  String _aiResponse = '';
  
  Timer? _timer;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _pausedDuration = Duration.zero;
  
  final TextEditingController _titleController = TextEditingController();
  String _selectedCategory = 'Programming';
  final List<String> _categories = ['Programming', 'Mathematics', 'History', 'Science', 'Other'];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    _voiceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      final lessonInitialized = await _lessonService.initialize();
      final voiceInitialized = await _voiceService.initialize();
      final ttsInitialized = await _ttsService.initialize();
      
      setState(() {
        _isInitialized = lessonInitialized && voiceInitialized && ttsInitialized;
      });
      
      if (!_isInitialized) {
        _showSnackBar('Failed to initialize recording services', isError: true);
      }
    } catch (e) {
      _logger.e('Error initializing services', error: e);
      _showSnackBar('Error initializing recording services', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record New Lesson'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Debug logging
            print('Back button pressed in RecordScreen');
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Recording status
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _isRecording 
                      ? Colors.red.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      size: 80,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording ? 'Recording...' : 'Ready to Record',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _isRecording ? Colors.red : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Recording controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Stop button
                  FloatingActionButton(
                    heroTag: null,
                    onPressed: _isRecording ? _stopRecording : null,
                    backgroundColor: _isRecording ? Colors.grey : Colors.grey.withOpacity(0.3),
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
                  
                  // Record/Pause button
                  FloatingActionButton.large(
                    heroTag: 'recordFAB',
                    onPressed: _isRecording ? _pauseRecording : _startRecording,
                    backgroundColor: _isRecording ? Colors.orange : Colors.red,
                    child: Icon(
                      _isRecording ? Icons.pause : Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  
                  // AI Analysis button
                  FloatingActionButton(
                    heroTag: 'analysisFAB',
                    onPressed: (_isRecording || _recordingDuration.inSeconds == 0 || _isProcessing) ? null : _processWithAI,
                    backgroundColor: (_isRecording || _recordingDuration.inSeconds == 0 || _isProcessing) 
                        ? Colors.grey.withOpacity(0.3) 
                        : Colors.blue,
                    child: Icon(
                      _isProcessing ? Icons.hourglass_empty : Icons.psychology,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Save button
                  FloatingActionButton(
                    heroTag: 'saveFAB',
                    onPressed: _isRecording ? null : _saveRecording,
                    backgroundColor: _isRecording ? Colors.grey.withOpacity(0.3) : Colors.green,
                    child: const Icon(Icons.save, color: Colors.white),
                  ),
                ],
              ),
              // AI Response display
              if (_aiResponse.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
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
                          Icon(Icons.psychology, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'AI Analysis',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiResponse,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Processing status
              if (_isProcessing) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isSpeaking ? 'Speaking AI response...' : 'Processing with AI...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 48),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recording Tips',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('• Speak clearly and at a steady pace'),
                    const Text('• Minimize background noise'),
                    const Text('• Structure your lesson with clear sections'),
                    const Text('• Use AI analysis for automatic transcription and insights'),
                    const Text('• Save recordings to build your lesson library'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (!_isInitialized) {
        _showSnackBar('Recording services not initialized', isError: true);
        return;
      }

      // Start audio recording
      final success = await _voiceService.startRecording();
      if (!success) {
        _showSnackBar('Failed to start recording', isError: true);
        return;
      }

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
        _recordingStartTime = DateTime.now();
        _pausedDuration = Duration.zero;
      });

      // Start timer for UI updates
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          final now = DateTime.now();
          final elapsed = now.difference(_recordingStartTime!) - _pausedDuration;
          setState(() {
            _recordingDuration = elapsed;
          });
        }
      });

      _logger.i('Started recording lesson');
    } catch (e) {
      _logger.e('Error starting recording', error: e);
      _showSnackBar('Error starting recording: $e', isError: true);
    }
  }

  Future<void> _pauseRecording() async {
    try {
      if (_isRecording) {
        // Calculate paused time for accurate duration tracking
        final pauseStart = DateTime.now();
        
        setState(() {
          _isRecording = false;
          _isPaused = true;
        });
        
        _timer?.cancel();
        
        // Note: VoiceService doesn't have pause, so we simulate it by stopping/starting
        // Make sure to capture the recording path when stopping
        final recordingPath = await _voiceService.stopRecording();
        if (recordingPath != null && recordingPath.isNotEmpty) {
          _currentRecordingPath = recordingPath;
          _logger.d('Captured recording path during pause: $_currentRecordingPath');
        }
        
        _logger.i('Paused recording at ${_formatDuration(_recordingDuration)}');
      } else if (_isPaused) {
        // Resume recording
        await _startRecording();
      }
    } catch (e) {
      _logger.e('Error pausing recording', error: e);
      _showSnackBar('Error pausing recording', isError: true);
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      
      if (_isRecording || _isPaused) {
        _currentRecordingPath = await _voiceService.stopRecording();
        
        setState(() {
          _isRecording = false;
          _isPaused = false;
        });
        
        _logger.i('Stopped recording: $_currentRecordingPath');
        
        // Debug: Check if file exists and show details
        if (_currentRecordingPath != null && _currentRecordingPath!.isNotEmpty) {
          try {
            final file = File(_currentRecordingPath!);
            final exists = await file.exists();
            if (exists) {
              final size = await file.length();
              _logger.i('Recording file exists: $exists, size: ${size} bytes');
              _showSnackBar('Recording stopped (${(size / 1024).round()}KB). Ready to save.');
            } else {
              _logger.w('Recording file does not exist at path: $_currentRecordingPath');
              _showSnackBar('Recording stopped but file not found!', isError: true);
            }
          } catch (fileError) {
            _logger.e('Error checking recording file', error: fileError);
          }
        } else {
          _logger.w('No recording path returned from voice service');
          _showSnackBar('Recording stopped but no file path!', isError: true);
        }
      }
    } catch (e) {
      _logger.e('Error stopping recording', error: e);
      _showSnackBar('Error stopping recording', isError: true);
    }
  }

  Future<void> _saveRecording() async {
    if (_recordingDuration.inSeconds == 0) {
      _showSnackBar('No recording to save', isError: true);
      return;
    }

    await _showSaveDialog();
  }

  Future<void> _showSaveDialog() async {
    _titleController.text = 'Lesson ${DateTime.now().day}/${DateTime.now().month}';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Recording'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Duration: ${_formatDuration(_recordingDuration)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _performSave();
    }
  }

  Future<void> _processWithAI() async {
    try {
      if (_currentRecordingPath == null || _currentRecordingPath!.isEmpty) {
        _showSnackBar('No recording to process', isError: true);
        return;
      }

      setState(() {
        _isProcessing = true;
        _currentTranscript = '';
        _aiResponse = '';
      });

      _showSnackBar('Transcribing audio...');

      // Step 1: Transcribe the recorded audio
      final transcriptResult = await _voiceService.transcribeAudioFile(_currentRecordingPath!);
      if (transcriptResult == null || transcriptResult.isEmpty) {
        setState(() {
          _isProcessing = false;
        });
        _showSnackBar('Failed to transcribe audio', isError: true);
        return;
      }

      setState(() {
        _currentTranscript = transcriptResult;
      });

      _showSnackBar('Processing with AI...');

      // Step 2: Send transcript to Gemma 3n
      final aiResult = await AIEdgeService.generateText(
        'Please analyze this lesson transcript and provide helpful insights, corrections, or summaries: "$transcriptResult"'
      );

      if (aiResult['success'] == true) {
        final response = aiResult['text'] ?? 'No response generated';
        setState(() {
          _aiResponse = response;
          _isSpeaking = true;
        });

        _showSnackBar('Speaking AI response...');

        // Step 3: Speak the AI response
        final ttsSuccess = await _ttsService.speak(response);
        
        if (ttsSuccess) {
          _logger.i('AI response spoken successfully');
        } else {
          _showSnackBar('AI processed but TTS failed', isError: true);
        }

        // Show performance metrics
        final inferenceTime = aiResult['inferenceTimeMs'] ?? 0;
        final tokensPerSec = aiResult['tokensPerSecond'] ?? 0;
        _showSnackBar('AI analysis complete • ${inferenceTime}ms • $tokensPerSec tokens/sec');

      } else {
        _showSnackBar('AI processing failed: ${aiResult['error']}', isError: true);
      }

      setState(() {
        _isProcessing = false;
        _isSpeaking = false;
      });

    } catch (e) {
      _logger.e('Error processing with AI', error: e);
      setState(() {
        _isProcessing = false;
        _isSpeaking = false;
      });
      _showSnackBar('Error processing with AI: $e', isError: true);
    }
  }

  Future<void> _performSave() async {
    try {
      final title = _titleController.text.trim();
      if (title.isEmpty) {
        _showSnackBar('Please enter a title', isError: true);
        return;
      }

      _logger.i('Attempting to save lesson: $title');
      _logger.i('Current recording path: $_currentRecordingPath');

      // Validate we have a recording to save
      if (_currentRecordingPath == null || _currentRecordingPath!.isEmpty) {
        _showSnackBar('No audio recording to save', isError: true);
        return;
      }

      // Check if the temporary file exists
      final tempFile = File(_currentRecordingPath!);
      if (!await tempFile.exists()) {
        _logger.e('Temporary audio file does not exist: $_currentRecordingPath');
        _showSnackBar('Audio file not found. Please record again.', isError: true);
        return;
      }

      String permanentAudioPath = '';

      try {
        // Generate a permanent file path using the lesson service
        permanentAudioPath = await _lessonService.startRecording(title, _selectedCategory);
        _logger.i('Generated permanent path: $permanentAudioPath');

        // Copy the temporary file to permanent location
        final permanentFile = File(permanentAudioPath);
        await tempFile.copy(permanentAudioPath);
        
        // Verify the permanent file was created
        if (await permanentFile.exists()) {
          final size = await permanentFile.length();
          _logger.i('Permanent audio file created: $size bytes');
        } else {
          throw Exception('Failed to create permanent audio file');
        }

        // Clean up temporary file
        try {
          await tempFile.delete();
          _logger.i('Temporary file cleaned up');
        } catch (cleanupError) {
          _logger.w('Failed to clean up temporary file: $cleanupError');
        }
      } catch (copyError) {
        _logger.e('Error copying audio file to permanent location', error: copyError);
        _showSnackBar('Failed to save audio file', isError: true);
        return;
      }

      // Save the lesson with transcript and AI analysis
      final lesson = await _lessonService.saveRecording(
        title: title,
        category: _selectedCategory,
        duration: _recordingDuration,
        audioFilePath: permanentAudioPath,
        transcript: _currentTranscript.isNotEmpty ? _currentTranscript : null,
        summary: _aiResponse.isNotEmpty ? _aiResponse : 'Recorded lesson about $title in $_selectedCategory',
      );

      _logger.i('Saved lesson: ${lesson.title} with audio: ${lesson.audioFilePath}');
      
      _showSnackBar('Lesson saved successfully!');
      
      // Reset state
      setState(() {
        _recordingDuration = Duration.zero;
        _isPaused = false;
        _currentTranscript = '';
        _aiResponse = '';
      });
      
      _titleController.clear();
      _currentRecordingPath = null;
      
      // Navigate back to home or history
      if (mounted) {
        context.go('/history');
      }
    } catch (e) {
      _logger.e('Error saving lesson', error: e);
      _showSnackBar('Error saving lesson: $e', isError: true);
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
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
