// lib/src/features/ai_status/presentation/pages/gemma_status_page.dart
// Updated to fix overflow completely

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../../../services/ai_edge_service.dart';
import '../../../../../services/gemma_download_service.dart';
import '../../../../core/services/logger_service.dart';
import '../widgets/status_card.dart';
import '../widgets/system_info_card.dart';
import '../widgets/memory_usage_card.dart';
import '../widgets/performance_metrics_card.dart';
import '../widgets/processor_utilization_card.dart';
import '../widgets/chat_interface.dart';
import '../widgets/voice_to_voice_widget.dart';

class GemmaStatusPage extends ConsumerStatefulWidget {
  const GemmaStatusPage({super.key});

  @override
  ConsumerState<GemmaStatusPage> createState() => _GemmaStatusPageState();
}

class _GemmaStatusPageState extends ConsumerState<GemmaStatusPage> {
  final _logger = FeatureLogger('GemmaStatus');
  Timer? _refreshTimer;

  // State variables (from your existing main.dart)
  bool _isModelDownloaded = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  double _downloadProgress = 0.0;
  String _status = 'Checking Gemma 3n model status...';
  String _response = '';
  Map<String, dynamic> _memoryUsage = {};
  Map<String, dynamic> _systemInfo = {};
  Map<String, dynamic> _performanceMetrics = {};
  Map<String, dynamic> _processorInfo = {};

  final TextEditingController _promptController = TextEditingController();
  final ScrollController _responseScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _promptController.dispose();
    _responseScrollController.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isInitialized) {
        _updateRealTimeMetrics();
      }
    });
  }

  Future<void> _updateRealTimeMetrics() async {
    if (!mounted) return;

    try {
      final futures = await Future.wait([
        AIEdgeService.getMemoryUsage(),
        AIEdgeService.getPerformanceMetrics(),
        AIEdgeService.getProcessorUtilization(),
      ]);

      if (mounted) {
        setState(() {
          _memoryUsage = futures[0];
          _performanceMetrics = futures[1];
          _processorInfo = futures[2];
        });
      }
    } catch (e) {
      _logger.e('Error updating real-time metrics', error: e);
    }
  }

  Future<void> _checkModelStatus() async {
    try {
      final isDownloaded = await GemmaDownloadService.isModelDownloaded();
      final systemInfo = await AIEdgeService.getSystemInfo();

      setState(() {
        _isModelDownloaded = isDownloaded;
        _systemInfo = systemInfo;
        _isInitialized = systemInfo['isInitialized'] ?? false;

        if (isDownloaded && !_isInitialized) {
          _status = 'Gemma 3n E4B downloaded - Ready to initialize';
        } else if (isDownloaded && _isInitialized) {
          _status = '✅ Gemma 3n E4B ready for inference';
        } else {
          _status = 'Gemma 3n E4B model not downloaded (~997MB required)';
        }
      });

      await _updateRealTimeMetrics();

      if (isDownloaded && !_isInitialized) {
        _initializeAIEdge();
      }
    } catch (e) {
      _logger.e('Error checking model status', error: e);
      setState(() {
        _status = 'Error checking model status: $e';
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isLoading = true;
      _status = 'Downloading Gemma 3n E4B model...';
      _downloadProgress = 0.0;
    });

    await GemmaDownloadService.downloadModel(
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          _status = 'Downloading Gemma 3n E4B... ${(progress * 100).toStringAsFixed(1)}%';
        });
      },
      onComplete: (modelPath) async {
        setState(() {
          _isModelDownloaded = true;
          _isLoading = false;
          _status = 'Gemma 3n E4B downloaded successfully - Initializing...';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        _initializeAIEdge();
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _status = 'Download failed: $error';
        });
        _showErrorSnackBar('Download failed: $error');
      },
    );
  }

  Future<void> _initializeAIEdge() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing Gemma 3n with AI Edge...';
    });

    final result = await AIEdgeService.initialize();

    if (result['success'] == true) {
      final systemInfo = await AIEdgeService.getSystemInfo();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _status = '✅ Gemma 3n E4B initialized successfully';
        _systemInfo = systemInfo;
        _response = 'Gemma 3n E4B is ready! Ask me anything - I can help with explanations, creative writing, coding, and more. All processing happens locally on your device for privacy.';
      });
      await _updateRealTimeMetrics();
    } else {
      setState(() {
        _isLoading = false;
        _status = '❌ Failed to initialize: ${result['error']}';
      });
      _showErrorSnackBar('Initialization failed: ${result['error']}');
    }
  }

  Future<void> _generateText() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showErrorSnackBar('Please enter a prompt first');
      return;
    }

    setState(() {
      _isLoading = true;
      _response = 'Gemma 3n is thinking...';
    });

    try {
      final result = await AIEdgeService.generateText(prompt);

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

        // Show performance info
        final inferenceTime = result['inferenceTimeMs'] ?? 0;
        final tokensPerSec = result['tokensPerSecond'] ?? 0;
        final processingUnit = result['processingUnit'] ?? 'CPU';
        _showSuccessSnackBar('Generated in ${inferenceTime}ms • $tokensPerSec tokens/sec • $processingUnit');

      } else {
        setState(() {
          _response = 'Error: ${result['error']}';
          _isLoading = false;
        });
        _showErrorSnackBar('Generation failed: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
      _showErrorSnackBar('Unexpected error: $e');
    }

    await _updateRealTimeMetrics();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Build chat interface using reusable widget
  Widget _buildChatInterface() {
    return ChatInterface(
      promptController: _promptController,
      responseScrollController: _responseScrollController,
      response: _response,
      isLoading: _isLoading,
      onGenerate: _generateText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Gemma 3n AI Edge'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateRealTimeMetrics,
            tooltip: 'Refresh metrics',
          ),
          IconButton(
            icon: Icon(_refreshTimer?.isActive == true ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_refreshTimer?.isActive == true) {
                _refreshTimer?.cancel();
              } else {
                _startPeriodicRefresh();
              }
              setState(() {});
            },
            tooltip: _refreshTimer?.isActive == true ? 'Pause auto-refresh' : 'Resume auto-refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Status Card
              StatusCard(
                status: _status,
                isLoading: _isLoading,
                downloadProgress: _downloadProgress,
              ),
              const SizedBox(height: 16),

              // System info cards in responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    // Wide screen: side by side
                    return Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: SystemInfoCard(systemInfo: _systemInfo)),
                              const SizedBox(width: 16),
                              Expanded(child: MemoryUsageCard(memoryUsage: _memoryUsage)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ProcessorUtilizationCard(processorInfo: _processorInfo),
                      ],
                    );
                  } else {
                    // Narrow screen: stacked
                    return Column(
                      children: [
                        SystemInfoCard(systemInfo: _systemInfo),
                        const SizedBox(height: 16),
                        MemoryUsageCard(memoryUsage: _memoryUsage),
                        const SizedBox(height: 16),
                        ProcessorUtilizationCard(processorInfo: _processorInfo),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Performance Metrics Card
              if (_performanceMetrics.isNotEmpty) ...[
                PerformanceMetricsCard(performanceMetrics: _performanceMetrics),
                const SizedBox(height: 16),
              ],

              // Action button or Chat interface
              if (!_isModelDownloaded) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _downloadModel,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Gemma 3n E4B (~997MB)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ] else if (!_isInitialized) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _initializeAIEdge,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Initialize Gemma 3n'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ] else ...[
                // Voice-to-voice interface
                const VoiceToVoiceWidget(),
                const SizedBox(height: 16),
                
                // Chat interface with fixed sizing
                _buildChatInterface(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}