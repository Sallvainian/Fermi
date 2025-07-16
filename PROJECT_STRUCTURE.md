# Teacher Dashboard Flutter Firebase - Project Structure

## Project Overview
This document provides a complete directory tree structure of the Teacher Dashboard Flutter Firebase project.

**Project Stats:**
- Total Files: 579
- Total Directories: 57+ 
- Last Updated: January 16, 2025

## Complete Directory Tree

```
teacher-dashboard-flutter-firebase/
├── .claude/
│   └── settings.local.json                    # Claude AI assistant local settings
├── .dart_tool/                                # Dart tooling and package cache
│   ├── dartpad/
│   │   └── web_plugin_registrant.dart
│   ├── package_config.json
│   ├── package_config_subset
│   ├── package_graph.json
│   └── version
├── .env                                       # Environment variables (gitignored)
├── .envs/                                     # Environment-specific configurations
│   └── teacher-dashboard-flutterfire-9f17990bfc84.json
├── .flutter-plugins-dependencies              # Flutter plugin dependency tracking
├── .git/                                      # Git repository data
│   ├── COMMIT_EDITMSG
│   ├── config
│   ├── description
│   ├── FETCH_HEAD
│   ├── HEAD
│   ├── hooks/                                 # Git hooks
│   │   ├── applypatch-msg.sample
│   │   ├── commit-msg.sample
│   │   ├── fsmonitor-watchman.sample
│   │   ├── post-update.sample
│   │   ├── pre-applypatch.sample
│   │   ├── pre-commit.sample
│   │   ├── pre-merge-commit.sample
│   │   ├── prepare-commit-msg.sample
│   │   ├── pre-push.sample
│   │   ├── pre-rebase.sample
│   │   ├── pre-receive.sample
│   │   ├── push-to-checkout.sample
│   │   ├── sendemail-validate.sample
│   │   └── update.sample
│   ├── index
│   ├── info/
│   │   └── exclude
│   ├── logs/                                  # Git logs
│   │   ├── HEAD
│   │   └── refs/
│   │       ├── heads/
│   │       │   └── main
│   │       └── remotes/
│   │           └── origin/
│   │               ├── add-claude-github-actions-1752548457778
│   │               ├── HEAD
│   │               └── main
│   ├── objects/                               # Git object database
│   │   ├── [200+ object files with hash names]
│   │   ├── info/
│   │   └── pack/
│   │       ├── pack-bbc542f13bb1443c5236811ec4364a1081dcb2b1.idx
│   │       ├── pack-bbc542f13bb1443c5236811ec4364a1081dcb2b1.pack
│   │       └── pack-bbc542f13bb1443c5236811ec4364a1081dcb2b1.rev
│   ├── ORIG_HEAD
│   ├── packed-refs
│   └── refs/                                  # Git references
│       ├── heads/
│       │   └── main
│       ├── remotes/
│       │   └── origin/
│       │       ├── add-claude-github-actions-1752548457778
│       │       ├── HEAD
│       │       └── main
│       └── tags/
├── .github/                                   # GitHub specific configurations
│   ├── dependa-bot.yml                       # Dependabot configuration
│   └── workflows/                             # GitHub Actions workflows
│       ├── apisec-scan.yml                    # API security scanning
│       ├── build.yml                          # Build workflow
│       ├── claude.yml                         # Claude AI workflow
│       └── qodana_code_quality.yml           # Code quality checks
├── .gitignore                                 # Git ignore rules
├── .idea/                                     # IntelliJ IDEA project settings
│   ├── .gitignore
│   ├── appInsightsSettings.xml
│   ├── betterCommentsSettings.xml
│   ├── caches/
│   │   └── deviceStreaming.xml
│   ├── dbnavigator.xml
│   ├── deviceManager.xml
│   ├── dictionaries/
│   │   └── project.xml
│   ├── discord.xml
│   ├── inspectionProfiles/
│   │   └── Project_Default.xml
│   ├── libraries/
│   │   ├── Dart_Packages.xml
│   │   ├── Dart_SDK.xml
│   │   ├── Flutter_Plugins.xml
│   │   └── google_api_grpc_proto_cloud_secretmanager_v1.xml
│   ├── material_theme_project_new.xml
│   ├── misc.xml
│   ├── modules.xml
│   ├── sonarlint.xml
│   ├── teacher-dashboard-flutter-firebase.iml
│   ├── vcs.xml
│   └── workspace.xml
├── .mcp.json                                  # MCP configuration
├── .sonarlint/                                # SonarLint configuration
│   └── connectedMode.json
├── .vscode/                                   # VS Code settings
│   └── settings.json
├── analysis_options.yaml                      # Dart static analysis configuration
├── android/                                   # Android platform files
│   ├── .gitignore
│   ├── .gradle/                               # Gradle build cache
│   │   ├── 8.13/
│   │   │   ├── checksums/
│   │   │   ├── executionHistory/
│   │   │   ├── expanded/
│   │   │   ├── fileChanges/
│   │   │   ├── fileHashes/
│   │   │   ├── gc.properties
│   │   │   └── vcsMetadata/
│   │   ├── buildOutputCleanup/
│   │   ├── nb-cache/
│   │   ├── noVersion/
│   │   └── vcs-1/
│   ├── .sonarlint/
│   │   └── connectedMode.json
│   ├── app/
│   │   ├── build.gradle.kts                   # App-level Gradle build file
│   │   ├── proguard-rules.pro                # ProGuard configuration
│   │   └── src/
│   │       ├── debug/
│   │       │   └── AndroidManifest.xml       # Debug manifest
│   │       ├── main/
│   │       │   ├── AndroidManifest.xml       # Main manifest
│   │       │   ├── java/
│   │       │   │   └── io/flutter/plugins/
│   │       │   │       └── GeneratedPluginRegistrant.java
│   │       │   ├── kotlin/
│   │       │   │   └── com/teacherdashboard/
│   │       │   │       ├── teacher_dashboard_flutter/
│   │       │   │       │   └── MainActivity.kt
│   │       │   │       └── teacher_dashboard_flutter_firebase/
│   │       │   │           └── MainActivity.kt
│   │       │   └── res/                      # Android resources
│   │       │       ├── drawable/
│   │       │       │   └── launch_background.xml
│   │       │       ├── drawable-v21/
│   │       │       │   └── launch_background.xml
│   │       │       ├── mipmap-hdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-mdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-xhdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-xxhdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── mipmap-xxxhdpi/
│   │       │       │   └── ic_launcher.png
│   │       │       ├── values/
│   │       │       │   └── styles.xml
│   │       │       └── values-night/
│   │       │           └── styles.xml
│   │       └── profile/
│   │           └── AndroidManifest.xml       # Profile manifest
│   ├── build.gradle.kts                       # Project-level Gradle build file
│   ├── gradle/
│   │   └── wrapper/
│   │       ├── gradle-wrapper.jar
│   │       └── gradle-wrapper.properties
│   ├── gradle.properties                      # Gradle properties
│   ├── gradlew                               # Gradle wrapper script (Unix)
│   ├── gradlew.bat                           # Gradle wrapper script (Windows)
│   ├── init.gradle                           # Gradle initialization script
│   ├── local.properties                      # Local SDK path (gitignored)
│   └── settings.gradle.kts                   # Gradle settings
├── assets/                                    # Application assets
│   └── images/
│       └── google_logo.png                   # Google sign-in logo
├── devtools_options.yaml                     # Flutter DevTools options
├── docker-compose.yml                        # Docker configuration
├── firebase.json                             # Firebase hosting configuration
├── firebase_options.dart                     # Firebase configuration for Dart
├── firestore.indexes.json                    # Firestore index definitions
├── firestore.rules                           # Firestore security rules
├── gemini.md                                 # Gemini AI documentation
├── ios/                                      # iOS platform files
│   ├── .gitignore
│   ├── Flutter/
│   │   ├── AppFrameworkInfo.plist
│   │   ├── Debug.xcconfig
│   │   ├── ephemeral/
│   │   │   ├── flutter_lldb_helper.py
│   │   │   └── flutter_lldbinit
│   │   ├── flutter_export_environment.sh
│   │   ├── Generated.xcconfig
│   │   └── Release.xcconfig
│   ├── Runner/
│   │   ├── AppDelegate.swift                 # iOS app delegate
│   │   ├── Assets.xcassets/                  # iOS assets
│   │   │   ├── AppIcon.appiconset/
│   │   │   │   ├── Contents.json
│   │   │   │   ├── Icon-App-1024x1024@1x.png
│   │   │   │   ├── Icon-App-20x20@1x.png
│   │   │   │   ├── Icon-App-20x20@2x.png
│   │   │   │   ├── Icon-App-20x20@3x.png
│   │   │   │   ├── Icon-App-29x29@1x.png
│   │   │   │   ├── Icon-App-29x29@2x.png
│   │   │   │   ├── Icon-App-29x29@3x.png
│   │   │   │   ├── Icon-App-40x40@1x.png
│   │   │   │   ├── Icon-App-40x40@2x.png
│   │   │   │   ├── Icon-App-40x40@3x.png
│   │   │   │   ├── Icon-App-60x60@2x.png
│   │   │   │   ├── Icon-App-60x60@3x.png
│   │   │   │   ├── Icon-App-76x76@1x.png
│   │   │   │   ├── Icon-App-76x76@2x.png
│   │   │   │   └── Icon-App-83.5x83.5@2x.png
│   │   │   └── LaunchImage.imageset/
│   │   │       ├── Contents.json
│   │   │       ├── LaunchImage.png
│   │   │       ├── LaunchImage@2x.png
│   │   │       ├── LaunchImage@3x.png
│   │   │       └── README.md
│   │   ├── Base.lproj/
│   │   │   ├── LaunchScreen.storyboard
│   │   │   └── Main.storyboard
│   │   ├── GeneratedPluginRegistrant.h
│   │   ├── GeneratedPluginRegistrant.m
│   │   ├── Info.plist
│   │   ├── Runner-Bridging-Header.h
│   │   └── upload_dsyms.sh
│   ├── Runner.xcodeproj/                     # Xcode project
│   │   ├── project.pbxproj
│   │   ├── project.xcworkspace/
│   │   │   ├── contents.xcworkspacedata
│   │   │   └── xcshareddata/
│   │   │       ├── IDEWorkspaceChecks.plist
│   │   │       └── WorkspaceSettings.xcsettings
│   │   └── xcshareddata/
│   │       └── xcschemes/
│   │           └── Runner.xcscheme
│   ├── Runner.xcworkspace/                   # Xcode workspace
│   │   ├── contents.xcworkspacedata
│   │   └── xcshareddata/
│   │       ├── IDEWorkspaceChecks.plist
│   │       └── WorkspaceSettings.xcsettings
│   └── RunnerTests/
│       └── RunnerTests.swift                 # iOS unit tests
├── lib/                                      # Main Flutter application code
│   ├── core/                                 # Core application setup
│   │   ├── app_initializer.dart             # App initialization logic
│   │   └── service_locator.dart             # Dependency injection setup
│   ├── firebase_options.dart                 # Firebase configuration
│   ├── main.dart                            # Application entry point
│   ├── models/                              # Data models
│   │   ├── assignment.dart                  # Assignment model
│   │   ├── calendar_event.dart              # Calendar event model
│   │   ├── call.dart                        # Video/voice call model
│   │   ├── chat_room.dart                   # Chat room model
│   │   ├── class_model.dart                 # Class/course model
│   │   ├── discussion_board.dart            # Discussion board model
│   │   ├── grade.dart                       # Grade model
│   │   ├── grade_analytics.dart             # Grade analytics model
│   │   ├── jeopardy_game.dart               # Jeopardy game model
│   │   ├── message.dart                     # Message model
│   │   ├── nav_item.dart                    # Navigation item model
│   │   ├── notification.dart                # Notification model
│   │   ├── notification_model.dart          # Notification data model
│   │   ├── student.dart                     # Student model
│   │   ├── submission.dart                  # Assignment submission model
│   │   └── user_model.dart                  # User model
│   ├── providers/                           # State management providers
│   │   ├── app_providers.dart               # Provider setup
│   │   ├── assignment_provider.dart         # Assignment state
│   │   ├── auth_provider.dart               # Authentication state
│   │   ├── calendar_provider.dart           # Calendar state
│   │   ├── call_provider.dart               # Call state
│   │   ├── chat_provider.dart               # Chat state
│   │   ├── class_provider.dart              # Class state
│   │   ├── discussion_provider.dart         # Discussion state
│   │   ├── grade_analytics_provider.dart    # Grade analytics state
│   │   ├── grade_provider.dart              # Grade state
│   │   ├── navigation_provider.dart         # Navigation state
│   │   ├── notification_provider.dart       # Notification state
│   │   ├── student_assignment_provider.dart # Student assignment state
│   │   ├── student_provider.dart            # Student state
│   │   └── theme_provider.dart              # Theme state
│   ├── repositories/                        # Data repositories
│   │   ├── assignment_repository.dart       # Assignment repository interface
│   │   ├── assignment_repository_impl.dart  # Assignment repository implementation
│   │   ├── auth_repository.dart             # Auth repository interface
│   │   ├── auth_repository_impl.dart        # Auth repository implementation
│   │   ├── base_repository.dart             # Base repository class
│   │   ├── calendar_repository.dart         # Calendar repository interface
│   │   ├── calendar_repository_impl.dart    # Calendar repository implementation
│   │   ├── chat_repository.dart             # Chat repository interface
│   │   ├── chat_repository_impl.dart        # Chat repository implementation
│   │   ├── class_repository.dart            # Class repository interface
│   │   ├── class_repository_impl.dart       # Class repository implementation
│   │   ├── discussion_repository.dart       # Discussion repository interface
│   │   ├── discussion_repository_impl.dart  # Discussion repository implementation
│   │   ├── firestore_repository.dart        # Firestore base repository
│   │   ├── firestore_repository_enhanced.dart # Enhanced Firestore repository
│   │   ├── grade_repository.dart            # Grade repository interface
│   │   ├── grade_repository_impl.dart       # Grade repository implementation
│   │   ├── mixins/                          # Repository mixins
│   │   │   └── pagination_mixin.dart        # Pagination functionality
│   │   ├── student_repository.dart          # Student repository interface
│   │   ├── student_repository_impl.dart     # Student repository implementation
│   │   ├── submission_repository.dart       # Submission repository interface
│   │   ├── submission_repository_impl.dart  # Submission repository implementation
│   │   ├── user_repository.dart             # User repository interface
│   │   └── user_repository_impl.dart        # User repository implementation
│   ├── routing/                             # Application routing
│   │   └── app_router.dart                  # Router configuration
│   ├── screens/                             # UI screens
│   │   ├── auth/                            # Authentication screens
│   │   │   ├── forgot_password_screen.dart  # Password recovery
│   │   │   ├── login_screen.dart            # Login screen
│   │   │   ├── role_selection_screen.dart   # Role selection
│   │   │   └── signup_screen.dart           # Registration screen
│   │   ├── calendar_screen.dart             # Calendar view
│   │   ├── chat/                            # Chat screens
│   │   │   ├── call_screen.dart             # Video/voice call
│   │   │   ├── chat_detail_screen.dart      # Chat conversation
│   │   │   ├── chat_list_screen.dart        # Chat list
│   │   │   ├── class_selection_screen.dart  # Class selection for chat
│   │   │   ├── group_creation_screen.dart   # Create group chat
│   │   │   ├── incoming_call_screen.dart    # Incoming call UI
│   │   │   └── user_selection_screen.dart   # Select users for chat
│   │   ├── common/                          # Common screens
│   │   │   ├── dashboard_screen.dart        # Main dashboard
│   │   │   └── placeholder_screen.dart      # Placeholder for development
│   │   ├── contact_support_screen.dart      # Support contact
│   │   ├── debug/                           # Debug screens
│   │   │   └── update_display_name_screen.dart # Update display name
│   │   ├── discussions/                     # Discussion screens
│   │   │   ├── create_board_dialog.dart     # Create discussion board
│   │   │   ├── create_thread_dialog.dart    # Create discussion thread
│   │   │   ├── discussion_board_detail_screen.dart # Board details
│   │   │   ├── discussion_boards_screen.dart # Discussion boards list
│   │   │   └── thread_detail_screen.dart    # Thread details
│   │   ├── games/                           # Educational games
│   │   │   ├── jeopardy_create_screen.dart  # Create Jeopardy game
│   │   │   ├── jeopardy_play_screen.dart    # Play Jeopardy game
│   │   │   └── jeopardy_screen.dart         # Jeopardy main screen
│   │   ├── help_screen.dart                 # Help documentation
│   │   ├── notifications_screen.dart        # Notifications
│   │   ├── settings_screen.dart             # App settings
│   │   ├── student/                         # Student-specific screens
│   │   │   ├── assignment_submission_screen.dart # Submit assignment
│   │   │   ├── assignments_screen.dart      # View assignments
│   │   │   ├── courses_screen.dart          # View courses
│   │   │   ├── enrollment_screen.dart       # Course enrollment
│   │   │   ├── grades_screen.dart           # View grades
│   │   │   ├── messages_screen.dart         # Student messages
│   │   │   ├── notifications_screen.dart    # Student notifications
│   │   │   └── student_dashboard_screen.dart # Student dashboard
│   │   └── teacher/                         # Teacher-specific screens
│   │       ├── assignments/                 # Assignment management
│   │       │   ├── assignment_create_screen.dart # Create assignment
│   │       │   ├── assignment_detail_screen.dart # Assignment details
│   │       │   └── assignment_edit_screen.dart   # Edit assignment
│   │       ├── assignments_screen.dart      # Assignments list
│   │       ├── classes/                     # Class management
│   │       │   └── classes_screen.dart      # Classes list
│   │       ├── grade_analytics_screen.dart  # Grade analytics
│   │       ├── gradebook/                   # Gradebook
│   │       │   └── gradebook_screen.dart    # Gradebook view
│   │       ├── messages_screen.dart         # Teacher messages
│   │       ├── students_screen.dart         # Students list
│   │       └── teacher_dashboard_screen.dart # Teacher dashboard
│   ├── services/                            # Business logic services
│   │   ├── assignment_service.dart          # Assignment operations
│   │   ├── auth_service.dart                # Authentication
│   │   ├── cache_service.dart               # Caching functionality
│   │   ├── calendar_service.dart            # Calendar operations
│   │   ├── chat_service.dart                # Chat functionality
│   │   ├── class_service.dart               # Class operations
│   │   ├── class_service_enhanced.dart      # Enhanced class service
│   │   ├── device_calendar_service.dart     # Device calendar integration
│   │   ├── device_calendar_service_factory.dart # Calendar service factory
│   │   ├── device_calendar_service_interface.dart # Calendar interface
│   │   ├── device_calendar_service_mobile.dart # Mobile calendar
│   │   ├── device_calendar_service_stub.dart # Calendar stub
│   │   ├── device_calendar_service_web.dart  # Web calendar
│   │   ├── error_handler_service.dart       # Error handling
│   │   ├── firebase_notification_service.dart # Firebase notifications
│   │   ├── firestore_service.dart           # Firestore operations
│   │   ├── firestore_service_enhanced.dart  # Enhanced Firestore service
│   │   ├── google_sign_in_service.dart      # Google authentication
│   │   ├── grade_analytics_service.dart     # Grade analytics
│   │   ├── logger_service.dart              # Logging
│   │   ├── navigation_service.dart          # Navigation
│   │   ├── notification_service.dart        # Local notifications
│   │   ├── performance_service.dart         # Performance monitoring
│   │   ├── presence_service.dart            # User presence tracking
│   │   ├── retry_service.dart               # Retry logic
│   │   ├── scheduled_messages_service.dart  # Scheduled messages
│   │   ├── student_service.dart             # Student operations
│   │   ├── submission_service.dart          # Assignment submissions
│   │   ├── validation_service.dart          # Input validation
│   │   └── webrtc_service.dart              # WebRTC for calls
│   ├── theme/                               # Application theming
│   │   ├── app_spacing.dart                 # Spacing constants
│   │   ├── app_theme.dart                   # Theme definition
│   │   └── app_typography.dart              # Typography styles
│   ├── utils/                               # Utility functions
│   │   └── error_handler.dart               # Error handling utilities
│   └── widgets/                             # Reusable widgets
│       ├── auth/                            # Authentication widgets
│       │   ├── auth_text_field.dart         # Custom text field
│       │   └── google_sign_in_button_web.dart # Google sign-in button
│       ├── common/                          # Common widgets
│       │   ├── adaptive_layout.dart         # Responsive layout
│       │   ├── app_card.dart                # Custom card widget
│       │   ├── app_drawer.dart              # Navigation drawer
│       │   ├── bottom_nav_bar.dart          # Bottom navigation
│       │   ├── common_widgets.dart          # Shared widgets
│       │   ├── custom_list_tile.dart        # Custom list tile
│       │   ├── empty_state.dart             # Empty state widget
│       │   ├── error_aware_stream_builder.dart # Error handling stream
│       │   ├── favorites_nav_bar.dart       # Favorites navigation
│       │   ├── firebase_error_boundary.dart # Firebase error handling
│       │   ├── global_error_handler.dart    # Global error widget
│       │   ├── responsive_layout.dart       # Responsive utilities
│       │   ├── stat_card.dart               # Statistics card
│       │   └── status_badge.dart            # Status indicator
│       ├── dashboard/                       # Dashboard widgets
│       │   └── online_users_card.dart       # Online users display
│       └── teacher/                         # Teacher widgets
│           └── create_class_dialog.dart     # Create class dialog
├── linux/                                   # Linux platform files
│   ├── .gitignore
│   ├── CMakeLists.txt
│   ├── flutter/
│   │   ├── CMakeLists.txt
│   │   ├── ephemeral/
│   │   │   └── .plugin_symlinks
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   └── runner/
│       ├── CMakeLists.txt
│       ├── main.cc
│       ├── my_application.cc
│       └── my_application.h
├── macos/                                   # macOS platform files
│   ├── .gitignore
│   ├── Flutter/
│   │   ├── ephemeral/
│   │   │   ├── flutter_export_environment.sh
│   │   │   └── Flutter-Generated.xcconfig
│   │   ├── Flutter-Debug.xcconfig
│   │   ├── Flutter-Release.xcconfig
│   │   └── GeneratedPluginRegistrant.swift
│   ├── Runner/
│   │   ├── AppDelegate.swift
│   │   ├── Assets.xcassets/
│   │   │   └── AppIcon.appiconset/
│   │   │       ├── app_icon_1024.png
│   │   │       ├── app_icon_128.png
│   │   │       ├── app_icon_16.png
│   │   │       ├── app_icon_256.png
│   │   │       ├── app_icon_32.png
│   │   │       ├── app_icon_512.png
│   │   │       ├── app_icon_64.png
│   │   │       └── Contents.json
│   │   ├── Base.lproj/
│   │   │   └── MainMenu.xib
│   │   ├── Configs/
│   │   │   ├── AppInfo.xcconfig
│   │   │   ├── Debug.xcconfig
│   │   │   ├── Release.xcconfig
│   │   │   └── Warnings.xcconfig
│   │   ├── DebugProfile.entitlements
│   │   ├── Info.plist
│   │   ├── MainFlutterWindow.swift
│   │   └── Release.entitlements
│   ├── Runner.xcodeproj/                   # Xcode project
│   │   ├── project.pbxproj
│   │   ├── project.xcworkspace/
│   │   │   └── xcshareddata/
│   │   │       └── IDEWorkspaceChecks.plist
│   │   └── xcshareddata/
│   │       └── xcschemes/
│   │           └── Runner.xcscheme
│   ├── Runner.xcworkspace/                  # Xcode workspace
│   │   ├── contents.xcworkspacedata
│   │   └── xcshareddata/
│   │       └── IDEWorkspaceChecks.plist
│   └── RunnerTests/
│       └── RunnerTests.swift
├── pubspec.lock                             # Package dependency lock file
├── pubspec.yaml                             # Package dependencies and metadata
├── qodana.yaml                              # Qodana code quality configuration
├── README.md                                # Project documentation
├── scripts/                                 # Utility scripts
│   ├── fetch_secrets.ps1                    # PowerShell secret fetcher
│   ├── fetch_secrets.sh                     # Bash secret fetcher
│   └── setup_secrets.ps1                    # PowerShell secret setup
├── sonar-project.properties                 # SonarQube configuration
├── storage.rules                            # Firebase Storage security rules
├── test/                                    # Unit and widget tests
│   └── widget_test.dart                     # Widget tests
├── tools/                                   # Development tools
│   └── README.md                            # Tools documentation
├── web/                                     # Web platform files
│   ├── favicon.png                          # Web favicon
│   ├── icons/                               # Web app icons
│   │   ├── Icon-192.png
│   │   ├── Icon-512.png
│   │   ├── Icon-maskable-192.png
│   │   └── Icon-maskable-512.png
│   ├── index.html                           # Web app entry point
│   ├── manifest.json                        # Web app manifest
│   └── web_server_config.md                 # Web server configuration guide
├── WEB_CONSOLE_WARNINGS.md                  # Web console warnings documentation
└── windows/                                 # Windows platform files
    ├── .gitignore
    ├── CMakeLists.txt
    ├── flutter/
    │   ├── ephemeral/
    │   │   └── .plugin_symlinks
    │   ├── generated_plugin_registrant.cc
    │   ├── generated_plugin_registrant.h
    │   └── generated_plugins.cmake
    └── runner/
        ├── CMakeLists.txt
        ├── flutter_window.cpp
        ├── flutter_window.h
        ├── main.cpp
        ├── resource.h
        ├── resources/
        │   └── app_icon.ico
        ├── runner.exe.manifest
        ├── Runner.rc
        ├── utils.cpp
        ├── utils.h
        ├── win32_window.cpp
        └── win32_window.h
```

## Key Directories Explained

### `/lib` - Application Source Code
The main Flutter application code organized by feature:
- **core/**: Core application setup and dependency injection
- **models/**: Data models representing entities
- **providers/**: State management using Provider pattern
- **repositories/**: Data access layer with Firebase integration
- **routing/**: Navigation configuration
- **screens/**: UI screens organized by feature and role
- **services/**: Business logic and external service integration
- **theme/**: Application theming and styling
- **utils/**: Utility functions and helpers
- **widgets/**: Reusable UI components

### Platform Directories
- **android/**: Android-specific configuration and native code
- **ios/**: iOS-specific configuration and native code
- **linux/**: Linux desktop support
- **macos/**: macOS desktop support
- **web/**: Web platform support
- **windows/**: Windows desktop support

### Configuration Files
- **pubspec.yaml**: Flutter package dependencies
- **firebase.json**: Firebase hosting configuration
- **firestore.rules**: Firestore security rules
- **.gitignore**: Git ignore patterns
- **analysis_options.yaml**: Dart linting rules

### Development Tools
- **.github/workflows/**: CI/CD pipelines
- **scripts/**: Build and deployment scripts
- **test/**: Test files
- **tools/**: Development utilities

## Notes
- Total file count includes all generated files, caches, and Git objects
- Some directories (like `.git/objects/`) contain many auto-generated files
- The project follows standard Flutter project structure with clean architecture principles
- Enhanced services (e.g., `firestore_service_enhanced.dart`) indicate performance optimizations