// lib/src/features/education/presentation/widgets/audio_player_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../../../core/services/audio_player_service.dart';
import '../../../../core/services/lesson_recording_service.dart';
import '../../../../core/services/logger_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final RecordedLesson lesson;
  final VoidCallback? onClose;

  const AudioPlayerWidget({
    super.key,
    required this.lesson,
    this.onClose,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> with TickerProviderStateMixin {
  final _logger = FeatureLogger('AudioPlayerWidget');
  final _audioPlayerService = AudioPlayerService();

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackRate = 1.0;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  late AnimationController _playButtonController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudioPlayer();
  }

  @override
  void dispose() {
    _playButtonController.dispose();
    _waveController.dispose();
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayerService.stop();
    super.dispose();
  }

  void _initializeAnimations() {
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  Future<void> _initializeAudioPlayer() async {
    try {
      final initialized = await _audioPlayerService.initialize();
      if (initialized) {
        _setupListeners();
        setState(() {
          _isInitialized = true;
        });
      } else {
        _showSnackBar('Failed to initialize audio player', isError: true);
      }
    } catch (e) {
      _logger.e('Error initializing audio player', error: e);
      _showSnackBar('Error initializing audio player', isError: true);
    }
  }

  void _setupListeners() {
    _stateSubscription = _audioPlayerService.stateStream?.listen((state) {
      setState(() {
        _isPlaying = state.isPlaying;
        _isPaused = state.isPaused;
      });
      
      if (state.isPlaying) {
        _playButtonController.forward();
        _waveController.repeat();
      } else {
        _playButtonController.reverse();
        _waveController.stop();
      }

      if (state.isCompleted) {
        _onPlaybackCompleted();
      }
    });

    _positionSubscription = _audioPlayerService.positionStream?.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _durationSubscription = _audioPlayerService.durationStream?.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  void _onPlaybackCompleted() {
    _showSnackBar('Lesson playback completed!');
  }

  Future<void> _togglePlayback() async {
    if (!_isInitialized) return;

    if (_isPlaying) {
      await _audioPlayerService.pause();
    } else if (_isPaused) {
      await _audioPlayerService.resume();
    } else {
      // Start playback
      if (widget.lesson.audioFilePath != null && widget.lesson.audioFilePath!.isNotEmpty) {
        final success = await _audioPlayerService.playFromFile(widget.lesson.audioFilePath!);
        if (!success) {
          _showSnackBar('Failed to play audio file', isError: true);
        }
      } else {
        _showSnackBar('No audio file available for this lesson', isError: true);
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayerService.stop();
  }

  Future<void> _seekTo(double value) async {
    final position = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
    await _audioPlayerService.seek(position);
  }

  Future<void> _changePlaybackRate() async {
    final rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = rates.indexOf(_playbackRate);
    final nextIndex = (currentIndex + 1) % rates.length;
    
    _playbackRate = rates[nextIndex];
    await _audioPlayerService.setPlaybackRate(_playbackRate);
    
    setState(() {});
    _showSnackBar('Playback speed: ${_playbackRate}x');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.play_circle_filled,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lesson.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.lesson.category} • ${_formatDuration(widget.lesson.duration)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Close Player',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Waveform animation (decorative)
            if (_isPlaying)
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(20, (index) {
                        final height = 4 + (30 * (0.5 + 0.5 * 
                          math.sin((_waveController.value * 2 * math.pi) + (index * 0.5))));
                        return Container(
                          width: 3,
                          height: height,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

            // Progress bar
            Column(
              children: [
                Slider(
                  value: _totalDuration.inMilliseconds > 0 
                      ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: _isInitialized ? _seekTo : null,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.grey[300],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Playback speed
                TextButton(
                  onPressed: _isInitialized ? _changePlaybackRate : null,
                  child: Text('${_playbackRate}x'),
                ),

                // Stop button
                IconButton(
                  onPressed: _isInitialized && (_isPlaying || _isPaused) ? _stopPlayback : null,
                  icon: const Icon(Icons.stop),
                  iconSize: 32,
                ),

                // Play/Pause button
                AnimatedBuilder(
                  animation: _playButtonController,
                  builder: (context, child) {
                    return IconButton(
                      onPressed: _isInitialized ? _togglePlayback : null,
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playButtonController,
                      ),
                      iconSize: 48,
                      color: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),

                // Skip forward 30s
                IconButton(
                  onPressed: _isInitialized ? () {
                    final newPosition = _currentPosition + const Duration(seconds: 30);
                    _seekTo(newPosition.inMilliseconds / _totalDuration.inMilliseconds);
                  } : null,
                  icon: const Icon(Icons.forward_30),
                  iconSize: 32,
                ),

                // Volume (placeholder)
                IconButton(
                  onPressed: () {
                    // Could add volume control dialog
                  },
                  icon: const Icon(Icons.volume_up),
                  iconSize: 32,
                ),
              ],
            ),

            // Status
            if (!_isInitialized)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Initializing audio player...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}