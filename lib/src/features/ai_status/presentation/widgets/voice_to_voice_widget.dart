// lib/src/features/ai_status/presentation/widgets/voice_to_voice_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../../../services/ai_edge_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/logger_service.dart';

class VoiceToVoiceWidget extends ConsumerStatefulWidget {
  const VoiceToVoiceWidget({super.key});

  @override
  ConsumerState<VoiceToVoiceWidget> createState() => _VoiceToVoiceWidgetState();
}

class _VoiceToVoiceWidgetState extends ConsumerState<VoiceToVoiceWidget>
    with TickerProviderStateMixin {
  final _logger = FeatureLogger('VoiceToVoice');
  final _voiceService = VoiceService();
  final _ttsService = TTSService();

  // State variables
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _currentTranscription = '';
  String _currentResponse = '';
  String _statusMessage = 'Initializing voice services...';
  VoiceRecordingState _recordingState = VoiceRecordingState.idle;
  TTSState _ttsState = TTSState.stopped;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Stream subscriptions
  StreamSubscription? _transcriptionSubscription;
  StreamSubscription? _recordingStateSubscription;
  StreamSubscription? _ttsStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _transcriptionSubscription?.cancel();
    _recordingStateSubscription?.cancel();
    _ttsStateSubscription?.cancel();
    _voiceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _statusMessage = 'Initializing voice services...';
      });

      // Initialize voice service
      final voiceInitialized = await _voiceService.initialize();
      if (!voiceInitialized) {
        setState(() {
          _statusMessage = 'Failed to initialize voice recognition';
        });
        return;
      }

      // Initialize TTS service
      final ttsInitialized = await _ttsService.initialize();
      if (!ttsInitialized) {
        setState(() {
          _statusMessage = 'Failed to initialize text-to-speech';
        });
        return;
      }

      // Set up stream listeners
      _transcriptionSubscription = _voiceService.transcriptionStream?.listen((transcription) {
        setState(() {
          _currentTranscription = transcription;
        });
      });

      _recordingStateSubscription = _voiceService.recordingStateStream?.listen((state) {
        setState(() {
          _recordingState = state;
          _isRecording = state == VoiceRecordingState.recording;
          _isListening = state == VoiceRecordingState.listening;
        });
        _updateAnimations();
      });

      _ttsStateSubscription = _ttsService.stateStream?.listen((state) {
        setState(() {
          _ttsState = state;
          _isSpeaking = state == TTSState.speaking;
        });
        _updateAnimations();
      });

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Voice services ready. Tap to start voice chat.';
      });

      _logger.i('Voice-to-voice services initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize voice services', error: e);
      setState(() {
        _statusMessage = 'Failed to initialize voice services: $e';
      });
    }
  }

  void _updateAnimations() {
    if (_isRecording || _isListening) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } else if (_isSpeaking) {
      _pulseController.repeat(reverse: true);
      _waveController.stop();
    } else {
      _pulseController.stop();
      _waveController.stop();
    }
  }

  Future<void> _startVoiceChat() async {
    try {
      if (!_isInitialized) {
        _showSnackBar('Voice services not initialized', isError: true);
        return;
      }

      setState(() {
        _statusMessage = 'Listening... Speak now!';
        _currentTranscription = '';
        _currentResponse = '';
      });

      // Start listening for speech
      final success = await _voiceService.startListening(
        timeout: const Duration(seconds: 30),
      );

      if (!success) {
        setState(() {
          _statusMessage = 'Failed to start voice recognition';
        });
        return;
      }

      // Wait for transcription with timeout
      Timer(const Duration(seconds: 30), () async {
        if (_isListening) {
          await _voiceService.stopListening();
          if (_currentTranscription.isNotEmpty) {
            await _processTranscription(_currentTranscription);
          } else {
            setState(() {
              _statusMessage = 'No speech detected. Please try again.';
            });
          }
        }
      });

    } catch (e) {
      _logger.e('Failed to start voice chat', error: e);
      setState(() {
        _statusMessage = 'Failed to start voice chat: $e';
      });
    }
  }

  Future<void> _stopVoiceChat() async {
    try {
      await _voiceService.stopListening();
      
      if (_currentTranscription.isNotEmpty) {
        await _processTranscription(_currentTranscription);
      } else {
        setState(() {
          _statusMessage = 'No speech detected. Please try again.';
        });
      }
    } catch (e) {
      _logger.e('Failed to stop voice chat', error: e);
    }
  }

  Future<void> _processTranscription(String transcription) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Processing your question...';
      });

      _logger.i('Processing transcription: $transcription');

      // Send to Gemma 3n model
      final result = await AIEdgeService.generateText(transcription);

      if (result['success'] == true) {
        final response = result['text'] ?? 'No response generated';
        setState(() {
          _currentResponse = response;
          _isProcessing = false;
          _statusMessage = 'Speaking response...';
        });

        // Speak the response
        await _ttsService.speak(response);

        setState(() {
          _statusMessage = 'Response complete. Tap to ask again.';
        });

        final inferenceTime = result['inferenceTimeMs'] ?? 0;
        final tokensPerSec = result['tokensPerSecond'] ?? 0;
        _showSnackBar('Generated in ${inferenceTime}ms • $tokensPerSec tokens/sec');

      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Failed to generate response: ${result['error']}';
        });
        _showSnackBar('Failed to generate response', isError: true);
      }
    } catch (e) {
      _logger.e('Failed to process transcription', error: e);
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error processing your question: $e';
      });
      _showSnackBar('Error processing your question', isError: true);
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _ttsService.stop();
      setState(() {
        _statusMessage = 'Speech stopped. Tap to ask again.';
      });
    } catch (e) {
      _logger.e('Failed to stop speaking', error: e);
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

  Color _getStatusColor() {
    if (_isRecording || _isListening) return Colors.red;
    if (_isProcessing) return Colors.orange;
    if (_isSpeaking) return Colors.blue;
    return Colors.green;
  }

  IconData _getStatusIcon() {
    if (_isRecording || _isListening) return Icons.mic;
    if (_isProcessing) return Icons.psychology;
    if (_isSpeaking) return Icons.volume_up;
    return Icons.mic_none;
  }

  String _getButtonText() {
    if (_isRecording || _isListening) return 'Stop Listening';
    if (_isProcessing) return 'Processing...';
    if (_isSpeaking) return 'Stop Speaking';
    return 'Start Voice Chat';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Voice-to-Voice Chat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status indicator
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: (_isRecording || _isListening || _isSpeaking) 
                      ? _pulseAnimation.value 
                      : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getStatusColor(),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      _getStatusIcon(),
                      size: 40,
                      color: _getStatusColor(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Status message
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Transcription display
            if (_currentTranscription.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hearing, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'You said:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentTranscription,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Response display
            if (_currentResponse.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.chat_bubble, color: Colors.green[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Gemma 3n Response:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentResponse,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Main action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isInitialized ? () async {
                  if (_isRecording || _isListening) {
                    await _stopVoiceChat();
                  } else if (_isSpeaking) {
                    await _stopSpeaking();
                  } else if (!_isProcessing) {
                    await _startVoiceChat();
                  }
                } : null,
                icon: _isProcessing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_getStatusIcon()),
                label: Text(_getButtonText()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getStatusColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}