# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that integrates Google's Gemma 3n E4B AI model using Google AI Edge for on-device inference. The app provides a comprehensive interface for downloading, initializing, and interacting with the Gemma 3n model while displaying real-time system metrics and performance data.

## Key Commands

### Development Commands
- `flutter run` - Run the app on connected device/emulator
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter test` - Run widget tests
- `flutter analyze` - Run static analysis (lint checking)
- `flutter doctor` - Check Flutter installation and dependencies

### Code Generation (when needed)
- `flutter packages pub run build_runner build` - Generate freezed/json serialization code
- `flutter packages pub run build_runner build --delete-conflicting-outputs` - Force rebuild generated code

### Platform-Specific
- `flutter run -d android` - Run on Android device
- `flutter run -d ios` - Run on iOS device
- `flutter run -d chrome` - Run on web browser
- `flutter clean` - Clean build artifacts

## Architecture

### Core Architecture Pattern
The app follows a feature-based architecture with clean separation of concerns:

```
lib/
├── main.dart                     # App entry point with initialization
├── services/                     # Top-level service layer
│   ├── ai_edge_service.dart      # AI model interaction via platform channels
│   └── gemma_download_service.dart # Model download management
└── src/
    ├── core/                     # Core utilities shared across features
    │   ├── services/             # Core services (logging, storage, errors)
    │   ├── theme/               # App theming
    │   └── routing/             # Navigation (for future expansion)
    ├── features/                # Feature modules
    │   ├── ai_status/           # Main AI status and chat interface
    │   ├── audio_recording/     # Future audio features
    │   ├── education/           # Future educational features
    │   ├── home/               # Future home screen
    │   ├── settings/           # Future settings
    │   └── translation/        # Future translation features
    └── shared/                  # Shared UI components
```

### State Management
- Uses **Riverpod** for state management
- Provider observers set up for debugging state changes
- Real-time metrics updated every 2 seconds via timers

### Platform Integration
- **Method Channels**: Used for native platform communication
  - `ai_edge_gemma` - AI model operations
  - `gemma_download` - Model download operations
- **AI Edge Integration**: Direct integration with Google AI Edge for Gemma 3n E4B model

### Key Services
- **AIEdgeService**: Main service for AI model operations (initialization, text generation, metrics)
- **GemmaDownloadService**: Handles model downloading and file management
- **LoggerService**: Centralized logging with feature-specific loggers
- **StorageService**: Local storage management using Hive
- **ErrorHandlerService**: Global error handling

## Important Implementation Details

### Model Management
- Gemma 3n E4B model (~997MB) downloaded to device storage
- Model file: `gemma_3n_e4b_int4.litertlm`
- Download URL: HuggingFace repository
- Minimum 1GB file size validation for integrity

### Performance Monitoring
- Real-time memory usage tracking
- Processor utilization monitoring (CPU/GPU)
- Inference performance metrics (tokens/second, latency)
- System information display

### UI Architecture
- Material 3 design system
- Responsive layout with breakpoints at 800px width
- Real-time metric updates with auto-refresh toggle
- Fixed-height chat interface to prevent overflow
- Status cards with live performance data

## Dependencies

### Core Dependencies
- `flutter_riverpod` - State management
- `go_router` - Navigation (prepared for future use)
- `dio` - HTTP client for API calls
- `hive` + `hive_flutter` - Local storage
- `shared_preferences` - Simple key-value storage
- `logger` - Logging framework
- `permission_handler` - Device permissions
- `path_provider` - File system paths
- `device_info_plus` - Device information
- `package_info_plus` - App information

### Development Dependencies
- `build_runner` - Code generation
- `freezed` - Data class generation
- `json_serializable` - JSON serialization
- `hive_generator` - Hive storage generation
- `flutter_lints` - Dart linting
- `mockito` - Testing framework

## Testing

### Widget Test Setup
- Basic widget test in `test/widget_test.dart`
- Uses `flutter_test` package
- Tests need to be updated to match current app structure (currently tests a counter that doesn't exist)

### Running Tests
```bash
flutter test                    # Run all tests
flutter test test/widget_test.dart  # Run specific test file
```

## Platform Configuration

### Android
- Min SDK: Check `android/app/build.gradle.kts`
- Permissions: Storage, microphone (for future features)
- Native code integration required for AI Edge

### iOS
- iOS deployment target: Check `ios/Runner/Info.plist`
- Permissions: Storage, microphone (for future features)
- Native code integration required for AI Edge

### Cross-Platform
- Web support available but AI Edge functionality limited
- Desktop support (Windows, macOS, Linux) configured

## Future Features (Prepared Architecture)
- Audio recording and processing
- Educational content modules
- Translation services
- Settings management
- Navigation between features (go_router ready)