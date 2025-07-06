// lib/src/core/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/audio_recording/presentation/pages/record_screen.dart';
import '../../features/education/presentation/pages/history_screen.dart';
import '../../features/education/presentation/pages/chat_screen.dart';
import '../../features/education/presentation/pages/lesson_chat_screen.dart';
import '../../features/ai_status/presentation/pages/gemma_status_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Home route
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Record lesson route
      GoRoute(
        path: '/record',
        name: 'record',
        builder: (context, state) => const RecordScreen(),
      ),

      // Lesson history route
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),

      // Chat route
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatScreen(),
      ),

      // Lesson-based chat route
      GoRoute(
        path: '/lesson-chat/:lessonId',
        name: 'lesson-chat',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId']!;
          return LessonChatScreen(lessonId: lessonId);
        },
      ),

      // AI Status route (existing functionality)
      GoRoute(
        path: '/ai-status',
        name: 'ai-status',
        builder: (context, state) => const GemmaStatusPage(),
      ),
    ],

    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page "${state.uri}" could not be found.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}