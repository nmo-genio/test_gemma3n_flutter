// lib/src/features/education/presentation/pages/history_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../../core/services/lesson_recording_service.dart';
import '../../../../core/services/logger_service.dart';
import '../widgets/audio_player_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _logger = FeatureLogger('HistoryScreen');
  final _lessonService = LessonRecordingService();
  
  List<RecordedLesson> _lessons = [];
  bool _isInitialized = false;
  StreamSubscription<List<RecordedLesson>>? _lessonsSubscription;

  String _selectedCategory = 'All';
  RecordedLesson? _playingLesson;
  final List<String> _categories = ['All', 'Programming', 'Mathematics', 'History', 'Science', 'Other'];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _lessonsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      final initialized = await _lessonService.initialize();
      setState(() {
        _isInitialized = initialized;
        _lessons = _lessonService.lessons;
      });
      
      if (initialized) {
        // Listen to lesson updates
        _lessonsSubscription = _lessonService.lessonsStream.listen((lessons) {
          if (mounted) {
            setState(() {
              _lessons = lessons;
            });
          }
        });
        _logger.i('History screen initialized with ${_lessons.length} lessons');
      }
    } catch (e) {
      _logger.e('Error initializing lesson service', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLessons = _selectedCategory == 'All' 
        ? _lessons 
        : _lessons.where((lesson) => lesson.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Lessons'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            print('Back button pressed in HistoryScreen');
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Category filter
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        ),
                      );
                    },
                  ),
                ),

                // Lessons list
                Expanded(
                  child: filteredLessons.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredLessons.length,
                          itemBuilder: (context, index) {
                            final lesson = filteredLessons[index];
                            return _buildLessonCard(lesson);
                          },
                        ),
                ),
              ],
            ),
            
            // Audio player overlay
            if (_playingLesson != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: AudioPlayerWidget(
                    lesson: _playingLesson!,
                    onClose: _closeAudioPlayer,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recordFAB',
        onPressed: () => context.push('/record'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLessonCard(RecordedLesson lesson) {
    // Debug logging
    _logger.d('Building lesson card for: ${lesson.title}, audioFilePath: ${lesson.audioFilePath}');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(lesson.category),
          child: Icon(
            _getCategoryIcon(lesson.category),
            color: Colors.white,
          ),
        ),
        title: Text(
          lesson.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lesson.category,
              style: TextStyle(
                color: _getCategoryColor(lesson.category),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(lesson.duration),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(lesson.dateRecorded),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                // Audio indicator
                if (lesson.audioFilePath != null && lesson.audioFilePath!.isNotEmpty)
                  Icon(
                    Icons.audiotrack,
                    size: 14,
                    color: Colors.green[600],
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play button (always visible for debugging)
            IconButton(
              icon: Icon(
                Icons.play_circle_filled,
                color: lesson.audioFilePath != null && lesson.audioFilePath!.isNotEmpty 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.grey,
                size: 32,
              ),
              onPressed: () => _showAudioPlayer(lesson),
              tooltip: 'Play Audio',
            ),
            // Menu button
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, lesson),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'audio',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text('Play Audio'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'chat',
                  child: Row(
                    children: [
                      Icon(Icons.chat),
                      SizedBox(width: 8),
                      Text('Chat About This Lesson'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 8),
                      Text('Share'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _playLesson(lesson),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No lessons found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record your first lesson to get started!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/record'),
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Record New Lesson'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Programming':
        return Colors.blue;
      case 'Mathematics':
        return Colors.green;
      case 'History':
        return Colors.orange;
      case 'Science':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Programming':
        return Icons.code;
      case 'Mathematics':
        return Icons.calculate;
      case 'History':
        return Icons.history_edu;
      case 'Science':
        return Icons.science;
      default:
        return Icons.book;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _playLesson(RecordedLesson lesson) {
    // Navigate to lesson-based chat
    context.push('/lesson-chat/${lesson.id}');
  }

  void _handleMenuAction(String action, RecordedLesson lesson) {
    switch (action) {
      case 'audio':
        _showAudioPlayer(lesson);
        break;
      case 'chat':
        _playLesson(lesson);
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sharing: ${lesson.title}')),
        );
        break;
      case 'delete':
        _showDeleteDialog(lesson);
        break;
    }
  }

  void _showAudioPlayer(RecordedLesson lesson) {
    _logger.i('Attempting to play audio for lesson: ${lesson.title}');
    _logger.i('Audio file path: ${lesson.audioFilePath}');
    
    if (lesson.audioFilePath == null || lesson.audioFilePath!.isEmpty) {
      _logger.w('No audio file path available for lesson: ${lesson.title}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio file available for this lesson'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _playingLesson = lesson;
    });
  }

  void _closeAudioPlayer() {
    setState(() {
      _playingLesson = null;
    });
  }

  void _showDeleteDialog(RecordedLesson lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Are you sure you want to delete "${lesson.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _lessonService.deleteLesson(lesson.id);
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lesson deleted')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete lesson'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Lessons'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Enter lesson title...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

