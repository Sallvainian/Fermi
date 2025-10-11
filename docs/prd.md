# Fermi Plus - Phase 1 Stabilization Enhancement PRD

## Intro Project Analysis and Context

### Scope Assessment

**Enhancement Complexity**: SIGNIFICANT - This is a comprehensive stabilization initiative requiring careful planning and multiple coordinated stories.

**Recommendation Rationale**: This PRD process is appropriate because:
- Multiple architectural concerns require systematic approach
- Test infrastructure needs coordination across entire codebase
- Staging environment setup requires planning and Firebase configuration
- Changes impact all features and require careful sequencing

This is NOT a simple feature addition - it's foundational work that enables future safe refactoring.

### Existing Project Overview

#### Analysis Source

**Document-project output available**: Yes
- Primary source: `docs/brownfield-architecture.md` (1,022 lines)
- Created: 2025-10-11 by Winston (Holistic System Architect)
- Comprehensive analysis including tech stack, technical debt, workarounds, security patterns
- Additional documentation: 50+ files in `docs/developer/` and `docs/user/`

#### Current Project State

**Summary from Winston's High Level Architecture**:

Fermi Plus is a **functional production system** (v0.9.6) built with Flutter 3.35.6 and Firebase that serves as a comprehensive education management platform. The project successfully targets 5 platforms (Web, Android, iOS, Windows, macOS) and provides real-time collaboration tools for teachers, students, and parents.

**Key Characteristics**:
- **Development Phase**: Production with technical debt from rapid MVP development
- **Development Approach**: "Vibe-coded" MVP evolved into production without formal architecture documentation
- **Current Status**: Functional production system requiring optimization and standardization
- **Tech Stack**: Flutter 3.35.6, Dart 3.9.2, Firebase Suite (Auth, Firestore, Storage, Functions, Messaging)
- **State Management**: Provider pattern (6.1.5+1) used consistently throughout
- **Navigation**: GoRouter 16.2.1 with auth-aware routing
- **Architecture**: Feature-first modular organization with shared services layer

**Core Features**:
- Multi-role authentication (teachers, students, parents, admin)
- Class management and student enrollment
- Assignment creation, submission, and grading
- Behavior points system (unique gamification feature)
- Real-time messaging and chat
- Discussion boards
- Calendar integration
- Grade analytics and reporting
- Educational games (Jeopardy)
- Push notifications (mobile) and local notifications (desktop)

### Documentation Analysis

#### Available Documentation

**Document-project analysis available** - Winston's comprehensive brownfield analysis includes:

✓ **Tech Stack Documentation** - Complete technology inventory with versions and notes (20+ technologies)
✓ **Source Tree/Architecture** - Full project structure with 1,000+ line file tree and module purposes
✓ **Coding Standards** - EditorConfig, analysis_options.yaml, flutter_lints configuration documented
✓ **API Documentation** - Firebase SDK integration patterns, Firestore collections, security rules
✓ **External API Documentation** - Platform-specific integrations (Calendar, OAuth, Notifications)
✓ **Technical Debt Documentation** - 7 critical debt items identified with priorities
- **UX/UI Guidelines** - Material 3 noted but no formal design system documentation
- **Other**: 50+ documentation files in docs/developer/ and docs/user/ directories

**Critical Gap Identified**: Almost no test documentation (only 1 unit test exists)

### Enhancement Scope Definition

#### Enhancement Type

Based on Winston's analysis and user requirements, this enhancement encompasses:

☑ **Bug Fix and Stability Improvements** - Primary focus on test coverage for stability
☑ **Performance/Scalability Improvements** - Staging environment enables performance validation
☑ **Technology Stack Upgrade** - Test infrastructure modernization
- New Feature Addition - Not primary focus
- Major Feature Modification - Not applicable
- Integration with New Systems - Not primary focus
- UI/UX Overhaul - Not applicable
- Other - Foundational stabilization work

#### Enhancement Description

**Phase 1: Stabilization Enhancement for Fermi Plus**

This enhancement establishes the foundational testing, staging, and documentation infrastructure required to safely modernize and optimize the Fermi Plus codebase. Currently at <5% test coverage with no staging environment, the project requires stabilization before architectural refactoring can proceed safely.

The enhancement focuses on implementing comprehensive test suites (unit, widget, integration), creating a staging Firebase environment, documenting critical user flows, and establishing quality guardrails that enable future optimization work without regression risk.

#### Impact Assessment

☑ **Significant Impact** (substantial existing code changes)

**Rationale**:
- Test infrastructure touches every feature module (15+ features)
- Staging environment requires Firebase project duplication and configuration
- Test setup requires dependency injection improvements (get_it standardization)
- Documentation of critical flows requires codebase analysis and user flow mapping
- Quality gates integration impacts CI/CD pipelines

**Architectural Changes Required**: Moderate
- Service layer modifications for testability (dependency injection)
- Provider modifications for test mocking
- Factory pattern refinement for platform service testing
- Firebase initialization modifications for test environment switching

### Goals and Background Context

#### Goals

If this stabilization enhancement is successful, we will achieve:

- **Test Coverage Goal**: Increase from <5% to 70%+ automated test coverage across unit, widget, and integration tests
- **Staging Environment**: Production-equivalent staging environment for pre-production validation
- **Critical Flow Documentation**: 10+ documented user flows covering authentication, class management, assignments, grading, and behavior points
- **Incident Response**: Documented playbook for production issue handling and rollback procedures
- **Quality Gates**: CI/CD enforcement of test passage, code coverage thresholds, and lint compliance
- **Testability Foundation**: Refactored service layer with consistent dependency injection enabling comprehensive test mocking
- **Regression Prevention**: Safety net enabling future refactoring without breaking production functionality

#### Background Context

**Why This Enhancement is Needed**:

Fermi Plus was successfully built as a "vibe-coded" MVP and evolved into production serving real educational institutions (Roselle Schools). The rapid development approach delivered value quickly but accumulated technical debt that now creates risk for future optimization.

Winston's brownfield analysis (October 2025) identified critical issues:
1. **Test coverage <5%** - Only 1 unit test exists, making refactoring HIGH RISK
2. **No staging environment** - Changes go directly from development to production
3. **Manual testing primary** - No automated regression detection
4. **Architecture documentation gap** - Until Winston's analysis, no comprehensive docs existed

**The Problem This Solves**:

Without tests and staging infrastructure, the codebase cannot be safely modernized. Every refactoring attempt risks breaking production functionality with no automated safety net. The development team cannot confidently optimize architecture, consolidate duplicate code, or standardize patterns because regression detection relies entirely on manual testing.

**How It Fits With Existing Project**:

This enhancement is **Phase 1 of Winston's 4-phase optimization roadmap**. It establishes the foundation that makes Phases 2-4 (Refactoring, Architecture, Quality) safe and achievable. By creating comprehensive tests first, subsequent optimization work can proceed with confidence and automation.

The enhancement aligns with the project's constitutional principles:
- Maintainability: Tests document expected behavior and enable safe evolution
- Privacy by design: Tests validate security rules and data access controls
- Platform-appropriate UX: Integration tests ensure consistent behavior across platforms

### Change Log

| Change | Date | Version | Description | Author |
|--------|------|---------|-------------|--------|
| Initial PRD Creation | 2025-10-11 | 0.1 | Phase 1 Stabilization PRD drafted | John (PM) |

---

## Requirements

### Functional

- **FR1**: The system SHALL implement unit tests for all service layer classes in `lib/shared/services/` covering success paths, error handling, and edge cases
- **FR2**: The system SHALL implement widget tests for all shared widgets in `lib/shared/widgets/` validating rendering, user interaction, and state changes
- **FR3**: The system SHALL implement integration tests for critical user flows: authentication (email, Google, Apple), class creation/enrollment, assignment submission, grading workflow, and behavior points assignment
- **FR4**: The system SHALL create a staging Firebase project with production-equivalent configuration including Auth, Firestore, Storage, Functions, and Messaging
- **FR5**: The system SHALL document 10+ critical user flows with step-by-step descriptions, expected behaviors, edge cases, and validation criteria
- **FR6**: The system SHALL create an incident response playbook documenting rollback procedures, Firebase console access, log analysis, and emergency contact procedures
- **FR7**: The system SHALL integrate test execution into CI/CD pipeline with automatic pull request validation and merge blocking on test failures
- **FR8**: The system SHALL implement test fixtures and mocking infrastructure for Firebase services (Auth, Firestore, Storage) enabling isolated unit testing
- **FR9**: The system SHALL refactor service layer to use consistent dependency injection via get_it service locator, enabling test mocking across all features
- **FR10**: The system SHALL implement provider test mocking utilities enabling widget tests to inject test providers without Firebase dependencies

### Non Functional

- **NFR1**: Test suite execution time SHALL NOT exceed 5 minutes for full suite, enabling rapid feedback during development
- **NFR2**: Test coverage SHALL achieve minimum 70% line coverage across lib/shared/ and lib/features/ directories, with path to 80%+ documented
- **NFR3**: Staging environment SHALL mirror production configuration with identical Firestore rules, Storage rules, Functions, and security settings
- **NFR4**: Test infrastructure SHALL NOT introduce breaking changes to existing production functionality or deployment processes
- **NFR5**: Documentation SHALL be maintainable by development team with markdown format, clear structure, and integration with existing docs/ directory
- **NFR6**: CI/CD pipeline SHALL provide clear feedback on test failures with specific error messages, file locations, and failure reasons
- **NFR7**: Test mocking infrastructure SHALL be reusable across features with consistent patterns documented in coding standards
- **NFR8**: Staging environment costs SHALL NOT exceed $50/month (Firebase free tier + minimal usage during testing)

### Compatibility Requirements

- **CR1: Existing Functionality Compatibility** - All existing features (assignments, grading, chat, behavior points, calendar, etc.) MUST continue functioning identically during and after test implementation with zero user-facing changes
- **CR2: Platform Compatibility** - Tests MUST be runnable on all development platforms (Linux, macOS, Windows) and CI/CD environment (GitHub Actions) without platform-specific failures
- **CR3: Firebase SDK Compatibility** - Test mocking MUST work with current Firebase SDK versions (Auth 6.0.1, Firestore 6.0.0, Storage 13.0.0) without requiring major version upgrades that could introduce breaking changes
- **CR4: Provider Pattern Compatibility** - Test infrastructure MUST integrate with existing Provider 6.1.5+1 state management pattern without requiring migration to alternative state management solutions
- **CR5: CI/CD Pipeline Compatibility** - Test integration MUST work with existing GitHub Actions workflows (01_ci.yml, 02_deploy_web.yml) and NOT disrupt current web deployment process
- **CR6: Development Workflow Compatibility** - Test execution MUST integrate with existing `flutter test` command and NOT require new test runners or frameworks unfamiliar to Flutter developers
- **CR7: Existing Documentation Compatibility** - New documentation MUST integrate with existing docs/ structure and NOT duplicate or conflict with Winston's brownfield-architecture.md or ContextKit's Context.md

---

## Technical Constraints and Integration Requirements

### Existing Technology Stack

**Core Framework and Language**:
- **Flutter**: 3.35.6 (stable channel) - Multi-platform support (Web, Android, iOS, Windows, macOS)
- **Dart**: 3.9.2 - Null-safe, strong typing
- **Test Framework**: Flutter Test SDK (built-in) + fake_cloud_firestore 4.0.0

**State Management**:
- **Provider**: 6.1.5+1 - Reactive state management with ChangeNotifier pattern
- **Test Constraint**: All widget tests must use Provider test utilities for mocking

**Backend and Database**:
- **Firebase Suite**: Latest versions
  - Firebase Auth 6.0.1 (multi-provider: Google, Apple, Email/Password, Username)
  - Cloud Firestore 6.0.0 (primary NoSQL database with offline persistence)
  - Firebase Storage 13.0.0 (file and media storage)
  - Firebase Functions (Cloud Functions for backend logic)
  - Firebase Messaging 16.0.0 (push notifications - mobile only)
  - Firebase Realtime Database 12.0.0 (presence system)
- **Test Constraint**: fake_cloud_firestore for Firestore mocking, custom mocks for Auth/Storage

**Testing Dependencies** (existing and new):
- **Current**: test ^1.25.15, mockito ^5.5.0, faker ^2.2.0, fake_cloud_firestore ^4.0.0
- **To Add**: integration_test (SDK), firebase_auth_mocks, firebase_storage_mocks (evaluate availability)
- **Constraint**: Use packages compatible with current Firebase SDK versions

**Development Tools**:
- **CI/CD**: GitHub Actions (workflows in .github/workflows/)
- **Code Quality**: flutter_lints ^6.0.0, analysis_options.yaml, .editorconfig
- **Build Tools**: build_runner ^2.7.0 for code generation

### Integration Approach

#### Test-Firebase Integration Strategy

**Unit Tests (lib/shared/services/, lib/features/*/data/services/)**:
- **Strategy**: Mock all Firebase dependencies using fake_cloud_firestore and custom Firebase Auth/Storage mocks
- **Dependency Injection**: Refactor services to accept Firebase instances via constructor injection (get_it service locator)
- **Isolation**: Tests run without real Firebase connection, using in-memory mocks
- **Example Pattern**:
  ```dart
  // Service refactored for testability
  class AuthService {
    final FirebaseAuth _auth;
    final FirebaseFirestore _firestore;

    AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;
  }

  // Test with mocks
  test('signInWithEmail success', () async {
    final mockAuth = MockFirebaseAuth();
    final fakeFirestore = FakeFirebaseFirestore();
    final service = AuthService(auth: mockAuth, firestore: fakeFirestore);
    // ... test logic
  });
  ```

**Widget Tests (lib/shared/widgets/, lib/features/*/presentation/)**:
- **Strategy**: Wrap widgets with Provider test harness injecting mock providers
- **Firebase Mocking**: Inject test-friendly providers that don't require Firebase initialization
- **Platform Testing**: Use platform channel mocking for platform-specific widgets (Calendar, Notifications)
- **Example Pattern**:
  ```dart
  testWidgets('Login button triggers auth', (tester) async {
    final mockAuthProvider = MockAuthProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ],
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    // ... interaction and assertion
  });
  ```

**Integration Tests (critical user flows)**:
- **Strategy**: Use Firebase Test Lab or local Firebase Emulator Suite for isolated integration testing
- **Staging Environment**: Integration tests run against staging Firebase project, NOT production
- **Platform Coverage**: Focus on web platform for CI/CD speed, manual mobile testing for platform-specific flows
- **Example Flows**: Auth → Class Creation → Assignment Creation → Submission → Grading

#### Staging Environment Integration Strategy

**Firebase Staging Project Setup**:
- **Project Name**: `fermi-plus-staging` (new Firebase project)
- **Configuration Parity**: Duplicate Firestore rules, Storage rules, Functions, Auth providers
- **Environment Switching**: Flutter flavor system or environment variables to switch Firebase configuration
- **Data Isolation**: Staging and production data completely separate, no cross-contamination risk
- **Cost Control**: Use Firebase free tier + minimal test data, auto-cleanup scripts for old test data

**Deployment Strategy**:
- **Development**: Local development → localhost Firebase emulators (optional)
- **Staging**: Feature branches → staging Firebase project for integration testing
- **Production**: Main branch → production Firebase project (existing workflow unchanged)

#### CI/CD Testing Integration Strategy

**GitHub Actions Workflow**:
- **Test Execution**: Run on every pull request before merge approval
- **Jobs**:
  1. Code quality (flutter analyze, dart format check) - existing
  2. **NEW**: Unit test execution (`flutter test test/unit/`)
  3. **NEW**: Widget test execution (`flutter test test/widget/`)
  4. **NEW**: Coverage report generation and validation (70% minimum)
- **Merge Blocking**: PR cannot merge if tests fail or coverage drops below threshold
- **Caching**: Cache Dart dependencies and Flutter SDK for faster CI runs

### Code Organization and Standards

#### Test File Structure

```
test/
├── unit/                           # Unit tests for services and business logic
│   ├── shared/
│   │   └── services/
│   │       ├── auth_service_test.dart
│   │       ├── firestore_service_test.dart
│   │       └── logger_service_test.dart
│   └── features/
│       ├── auth/
│       │   └── data/services/
│       │       └── auth_service_test.dart
│       └── classes/
│           └── data/services/
│               └── class_service_test.dart
├── widget/                         # Widget tests for UI components
│   ├── shared/
│   │   └── widgets/
│   │       ├── custom_button_test.dart
│   │       └── loading_indicator_test.dart
│   └── features/
│       ├── auth/
│       │   └── presentation/
│       │       └── login_screen_test.dart
│       └── classes/
│           └── presentation/
│               └── class_list_screen_test.dart
├── integration/                    # Integration tests for user flows
│   ├── auth_flow_test.dart
│   ├── class_management_flow_test.dart
│   ├── assignment_flow_test.dart
│   └── grading_flow_test.dart
├── fixtures/                       # Test data and mocks
│   ├── mock_firebase_auth.dart
│   ├── mock_firebase_storage.dart
│   ├── test_data.dart
│   └── user_fixtures.dart
└── helpers/                        # Test utilities
    ├── provider_test_wrapper.dart
    ├── firebase_test_helpers.dart
    └── widget_test_helpers.dart
```

#### Naming Conventions

**Test File Naming**: `{source_file}_test.dart` (e.g., `auth_service.dart` → `auth_service_test.dart`)
**Test Group Naming**: Match class or widget name (e.g., `group('AuthService', () { ... })`)
**Test Case Naming**: Descriptive behavior-driven format (e.g., `test('signInWithEmail returns user on success', () { ... })`)
**Mock Class Naming**: `Mock{ClassName}` (e.g., `MockAuthService`, `MockAuthProvider`)

#### Coding Standards for Tests

- **Arrange-Act-Assert**: Structure all tests with clear setup, execution, and verification sections
- **Single Responsibility**: Each test validates one specific behavior
- **No Test Interdependence**: Tests must run independently in any order
- **Descriptive Assertions**: Use meaningful failure messages (`expect(result, isTrue, reason: 'Expected user to be authenticated')`
- **Test Data Fixtures**: Use fixtures/ for reusable test data, no hardcoded test data in test files
- **Mock Minimalism**: Only mock external dependencies (Firebase, HTTP), not internal domain logic

### Deployment and Operations

#### Build Process Integration

**No Impact on Existing Build**:
- Test implementation does NOT affect production build commands
- Existing Flutter build commands remain unchanged:
  - `flutter build web --release`
  - `flutter build apk --release`
  - `flutter build ios --release`
- Tests are development-only, not included in production bundles

#### Staging Environment Deployment Strategy

**Staging Deployment Process**:
1. **Firebase Project Setup**: Create `fermi-plus-staging` Firebase project via Firebase Console
2. **Configuration Files**: Generate `firebase_options_staging.dart` via FlutterFire CLI
3. **Environment Switching**: Use Dart compilation constants or environment variables
4. **Automated Deployment**: GitHub Actions workflow for staging deployment on staging branch
5. **Manual Testing**: QA team tests against staging environment before production release

**Staging Access Control**:
- **Firebase Console**: Grant development team member access to staging project
- **Test Accounts**: Create test teacher/student accounts with @fermi-plus-staging.com domain
- **Data Isolation**: Firestore rules enforce staging-only data access

#### Monitoring and Logging

**Test Execution Monitoring**:
- **CI/CD Logs**: GitHub Actions workflow logs show test execution results
- **Coverage Reports**: Generate HTML coverage reports, upload to GitHub Actions artifacts
- **Failure Notifications**: GitHub PR status checks notify on test failures

**Staging Environment Monitoring**:
- **Firebase Console**: Monitor Firestore usage, Storage usage, Function invocations
- **Cost Alerts**: Set up Firebase billing alerts at $25 and $40 thresholds
- **LoggerService**: Staging logs tagged with `[STAGING]` prefix for filtering

#### Configuration Management

**Environment-Specific Configuration**:
```dart
// lib/shared/core/environment_config.dart (NEW)
enum Environment { development, staging, production }

class EnvironmentConfig {
  static Environment current = Environment.development;

  static FirebaseOptions get firebaseOptions {
    switch (current) {
      case Environment.staging:
        return DefaultFirebaseOptions.staging; // NEW
      case Environment.production:
        return DefaultFirebaseOptions.currentPlatform;
      case Environment.development:
      default:
        return DefaultFirebaseOptions.currentPlatform;
    }
  }
}
```

### Risk Assessment and Mitigation

#### Technical Risks

**Risk 1: Test Implementation Breaking Production Code**
- **Probability**: Medium
- **Impact**: High (production outage)
- **Mitigation**:
  - Implement tests feature-by-feature, NOT all at once
  - Each PR includes BOTH tests AND verification that existing functionality still works
  - Staging environment validates changes before production deployment
  - Rollback plan: Git revert + immediate production deployment

**Risk 2: Firebase Mocking Incomplete or Inaccurate**
- **Probability**: High (fake_cloud_firestore doesn't support all Firestore features)
- **Impact**: Medium (false positive tests, bugs slip through)
- **Mitigation**:
  - Document known fake_cloud_firestore limitations (e.g., collection group queries limited)
  - Integration tests against real Firebase (staging) supplement unit tests
  - Regular comparison of mock behavior vs real Firebase behavior
  - Use Firebase Local Emulator Suite for higher-fidelity testing when mocks insufficient

**Risk 3: Refactoring Services for Testability Introduces Bugs**
- **Probability**: Medium
- **Impact**: High (regression in core services)
- **Mitigation**:
  - Start with least critical services (e.g., CapsLockService, ValidationService)
  - Manual testing regression checklist after each service refactoring
  - Staging environment testing before production merge
  - Feature flags to quickly disable new dependency injection if issues detected

**Risk 4: CI/CD Pipeline Slowdown**
- **Probability**: High (test suite grows over time)
- **Impact**: Low (developer frustration, slower deployments)
- **Mitigation**:
  - NFR1 constraint: 5-minute maximum test suite execution
  - Parallelize test execution in CI (GitHub Actions matrix strategy)
  - Cache Flutter SDK and dependencies aggressively
  - Optimize slow tests or move to nightly test suite

#### Integration Risks

**Risk 5: Provider Pattern Doesn't Play Well with Testing**
- **Probability**: Medium (Provider testing has quirks)
- **Impact**: Medium (widget tests difficult or flaky)
- **Mitigation**:
  - Create reusable `ProviderTestWrapper` utility early
  - Document Provider testing patterns in test helpers
  - Investigate `provider_test` package or similar community solutions
  - Fallback: Use pump and settle patterns with real providers in limited cases

**Risk 6: Platform-Specific Tests Fail on CI**
- **Probability**: High (Windows/Mac platform channels don't work in Linux CI)
- **Impact**: Low (expected behavior, requires documentation)
- **Mitigation**:
  - Document which tests require specific platforms
  - Use `@TestOn('vm')` annotations to skip web-incompatible tests
  - Mock platform channels for CI environment
  - Manual testing on native platforms for platform-specific features

#### Deployment Risks

**Risk 7: Staging Environment Misconfiguration**
- **Probability**: Medium
- **Impact**: Medium (false confidence in staging, production issues)
- **Mitigation**:
  - Checklist for staging setup: Firestore rules, Storage rules, Auth providers, Functions
  - Automated staging environment validation script (checks rule parity)
  - Regular manual comparison: staging vs production configuration
  - Document staging-production differences (e.g., email domains)

**Risk 8: Test Dependencies Conflict with Production Dependencies**
- **Probability**: Low (pub.yaml dev_dependencies separated)
- **Impact**: Low (build errors, easily resolved)
- **Mitigation**:
  - Keep test dependencies in dev_dependencies section only
  - Run production builds after adding test dependencies to verify no impact
  - CI workflow includes production build validation

#### Mitigation Strategies Summary

**Incremental Rollout**: Implement tests feature-by-feature over multiple PRs, NOT big bang
**Staging Validation**: Every change tested in staging before production merge
**Rollback Readiness**: Git revert commands documented, practiced, and accessible
**Documentation**: Comprehensive test documentation in `docs/developer/testing/`
**Team Training**: Knowledge sharing sessions on test patterns and troubleshooting
**Monitoring**: CI/CD dashboards show test health, coverage trends, and failure rates

---

## Epic and Story Structure

### Epic Approach

**Epic Structure Decision**: **Single Comprehensive Epic** - "Phase 1: Stabilization Infrastructure"

**Rationale Based on Project Analysis**:

This enhancement should be structured as ONE epic because all components are tightly interconnected and serve a unified goal: establishing the testing and staging foundation that enables safe future optimization.

**Why Single Epic (NOT Multiple)**:
1. **Interdependency**: Test infrastructure requires staging environment for integration tests. Documentation depends on test examples. CI/CD changes depend on test structure. These aren't independent features - they're components of one system.

2. **Sequential Dependencies**: Stories must execute in logical order:
   - Test fixtures/helpers BEFORE unit tests (need test utilities first)
   - Unit tests for services BEFORE widget tests (widgets depend on services)
   - Staging environment BEFORE integration tests (need test environment)
   - Documentation AFTER implementation (document what exists)

3. **Cohesive Goal**: All work delivers SINGLE outcome: "Production system with 70%+ test coverage and staging validation capability". This is one deliverable, not multiple separate features.

4. **Risk Management**: Single epic allows coherent rollout strategy. Starting a second epic before stabilization completes would create fragmented progress and increased risk.

5. **Brownfield Best Practice**: For existing production systems, comprehensive stabilization work should be treated as unified foundation work, not scattered feature additions.

**When Multiple Epics Would Be Appropriate**:
- If user requested unrelated enhancements (e.g., "Add tests AND redesign UI") - separate concerns
- If targeting different phases of Winston's roadmap simultaneously (Stabilization + Refactoring) - different objectives
- If enhancement scope was genuinely independent features with no shared dependencies

**For Phase 1 Stabilization**: Single epic is correct approach. Future PRDs for Phase 2 (Refactoring), Phase 3 (Architecture), Phase 4 (Quality) will each be their own epics, but Phase 1 stands as one coherent unit of work.

---

## Epic 1: Phase 1 Stabilization Infrastructure

**Epic Goal**: Establish comprehensive testing infrastructure (70%+ coverage), staging environment, and quality documentation that enables safe refactoring and optimization of the Fermi Plus codebase without regression risk.

**Integration Requirements**:
- All tests must integrate with existing Provider state management pattern
- All infrastructure must work with current Firebase SDK versions (no major upgrades required)
- All changes must maintain backward compatibility with existing production functionality
- All new infrastructure must integrate with existing CI/CD workflows (GitHub Actions)

**Story Sequencing Strategy**: Stories ordered to minimize risk to existing system by establishing foundation first, then layering tests systematically. Each story includes verification that existing features still work.

### Story 1.1: Test Infrastructure Foundation

As a **developer**,
I want **test fixtures, mocking utilities, and helper functions for Firebase and Provider testing**,
so that **I can write isolated, reliable tests without requiring live Firebase connections or complex test setup**.

#### Acceptance Criteria

1. **Test directory structure created** matching the structure defined in Technical Constraints section (test/unit/, test/widget/, test/integration/, test/fixtures/, test/helpers/)
2. **Firebase mock utilities implemented** in test/fixtures/:
   - MockFirebaseAuth with sign-in/sign-out/user state simulation
   - MockFirebaseStorage with upload/download simulation
   - FakeFirebaseFirestore integration (using existing fake_cloud_firestore package)
3. **Provider test wrapper utility** created in test/helpers/provider_test_wrapper.dart enabling easy Provider injection for widget tests
4. **Test data fixtures** created in test/fixtures/test_data.dart with sample users, classes, assignments for reuse across tests
5. **Documentation** added to test/README.md explaining test infrastructure usage patterns

#### Integration Verification

- **IV1**: Existing Firebase initialization in lib/shared/core/app_initializer.dart continues working without modifications
- **IV2**: Existing Provider setup in lib/shared/core/app_providers.dart continues working without changes
- **IV3**: Production app still runs successfully on web after test infrastructure additions

### Story 1.2: Shared Service Unit Tests

As a **developer**,
I want **unit tests for all shared service layer classes (lib/shared/services/)**,
so that **core business logic is validated and regressions in foundational services are caught automatically**.

#### Acceptance Criteria

1. **Unit tests implemented** for all 10 shared services:
   - logger_service_test.dart (logging levels, tags, error handling)
   - firestore_service_test.dart (retry logic, error handling, connection management)
   - error_handler_service_test.dart (error categorization, logging integration)
   - cache_service_test.dart (cache operations, memory management)
   - navigation_service_test.dart (route navigation, state preservation)
   - validation_service_test.dart (form validation rules)
   - retry_service_test.dart (exponential backoff, max retry logic)
   - region_detector_service_test.dart (region detection logic)
   - caps_lock_service_test.dart (keyboard state detection - platform-specific)
   - firestore_repository_test.dart (generic repository pattern)
2. **Test coverage** achieves 80%+ line coverage for lib/shared/services/ directory
3. **All tests pass** with no failures or flaky tests
4. **Tests execute in <30 seconds** for shared services test suite

#### Integration Verification

- **IV1**: Existing features using these services (auth, classes, assignments) continue functioning correctly
- **IV2**: Production LoggerService output unchanged (no regression in logging behavior)
- **IV3**: Manual smoke test confirms: login, class creation, assignment creation all work

### Story 1.3: Service Layer Testability Refactoring

As a **developer**,
I want **services refactored to accept Firebase dependencies via constructor injection**,
so that **services can be tested in isolation with mocked Firebase instances instead of requiring live connections**.

#### Acceptance Criteria

1. **AuthService refactored** (lib/features/auth/data/services/auth_service.dart) to accept FirebaseAuth and FirebaseFirestore via constructor with default fallback to instances
2. **ClassService refactored** (lib/features/classes/data/services/class_service.dart) to accept FirebaseFirestore via constructor
3. **AssignmentService refactored** (lib/features/assignments/data/services/assignment_service.dart) to accept FirebaseFirestore and FirebaseStorage via constructor
4. **Service locator updated** (lib/shared/core/service_locator.dart) to register refactored services with get_it
5. **Existing service consumers** (providers, screens) continue using services WITHOUT changes (backward compatibility maintained)
6. **Unit tests added** for refactored services demonstrating mock injection pattern

#### Integration Verification

- **IV1**: All existing auth flows work (email login, Google sign-in, Apple sign-in, username login)
- **IV2**: Class creation, editing, deletion continue functioning
- **IV3**: Assignment creation and submission workflows unaffected
- **IV4**: Production build succeeds with no compilation errors

### Story 1.4: Authentication Feature Unit Tests

As a **developer**,
I want **comprehensive unit tests for authentication services and logic**,
so that **critical security-related functionality is thoroughly validated and protected from regressions**.

#### Acceptance Criteria

1. **AuthService unit tests** covering:
   - Email/password sign-in success and failure cases
   - Google OAuth flow simulation
   - Apple OAuth flow simulation
   - Username authentication flow
   - Sign-out functionality
   - Domain-based role assignment validation (teacher vs student domains)
2. **UsernameAuthService tests** for custom username lookup logic
3. **Desktop OAuth handler tests** (mock server behavior, token exchange)
4. **Auth error handling tests** (invalid credentials, network errors, Firebase errors)
5. **Test coverage** 75%+ for lib/features/auth/data/services/ directory
6. **All tests pass** consistently with no flaky behavior

#### Integration Verification

- **IV1**: Existing login screen continues working for all auth methods
- **IV2**: Role assignment logic unchanged (teachers get teacher role, students get student role)
- **IV3**: OAuth flows on desktop platform continue working
- **IV4**: Auth state persistence after app restart still functions

### Story 1.5: Staging Firebase Environment Setup

As a **developer**,
I want **a production-equivalent staging Firebase project with environment switching capability**,
so that **I can test changes in isolation before deploying to production and run integration tests safely**.

#### Acceptance Criteria

1. **Staging Firebase project created**: `fermi-plus-staging` in Firebase Console
2. **Firestore rules duplicated** from production to staging (797-line rules file deployed)
3. **Storage rules duplicated** from production to staging
4. **Auth providers configured**: Email/Password, Google (with test OAuth client), Apple (test mode)
5. **Environment configuration** implemented:
   - lib/shared/core/environment_config.dart created with Environment enum
   - firebase_options_staging.dart generated via FlutterFire CLI
   - Flutter flavor or environment variable system for switching environments
6. **Test accounts created**: test-teacher@fermi-plus-staging.com, test-student@fermi-plus-staging.com
7. **Cost monitoring** configured: Firebase billing alerts at $25 and $40

#### Integration Verification

- **IV1**: Production Firebase configuration unchanged and still used for main branch builds
- **IV2**: Can manually switch to staging environment and app connects successfully
- **IV3**: Staging and production data completely isolated (no cross-contamination)
- **IV4**: Production deployment workflow continues functioning without changes

### Story 1.6: Core Feature Unit Tests (Classes, Assignments)

As a **developer**,
I want **unit tests for critical feature services: classes and assignments**,
so that **core educational features are protected from regressions and test coverage increases toward 70% goal**.

#### Acceptance Criteria

1. **ClassService unit tests** covering:
   - Class creation, reading, updating, deletion (CRUD)
   - Student enrollment and un-enrollment
   - Class listing queries
   - Teacher-class association logic
   - Error handling for invalid class operations
2. **AssignmentService unit tests** covering:
   - Assignment creation and configuration
   - Assignment submission workflows
   - File upload/download simulation (mocked Storage)
   - Grade recording logic
   - Due date validation
3. **SubmissionService unit tests** for student submission handling
4. **Test coverage** 70%+ for lib/features/classes/ and lib/features/assignments/
5. **All tests pass** with consistent, non-flaky behavior

#### Integration Verification

- **IV1**: Class management workflows continue functioning (create, view, edit classes)
- **IV2**: Assignment creation and submission features work unchanged
- **IV3**: File uploads for assignments still function correctly
- **IV4**: Grading workflows remain functional

### Story 1.7: Shared Widget Tests

As a **developer**,
I want **widget tests for reusable shared UI components**,
so that **common UI elements are validated for rendering and interaction behavior across features**.

#### Acceptance Criteria

1. **Widget tests implemented** for lib/shared/widgets/ components:
   - Custom button widgets (interaction, states, styling)
   - Loading indicators (display, animation)
   - Form input widgets (validation, state)
   - Navigation components
   - Any other reusable widgets identified
2. **Provider test wrapper** used successfully to inject mock providers
3. **Widget interaction tests** validate button taps, form submissions, navigation triggers
4. **Widget rendering tests** validate visual output for different states
5. **Tests execute in <1 minute** for shared widgets test suite

#### Integration Verification

- **IV1**: Existing screens using shared widgets continue rendering correctly
- **IV2**: Button interactions throughout app still trigger correct actions
- **IV3**: Form validation behavior unchanged across features

### Story 1.8: Authentication Flow Widget Tests

As a **developer**,
I want **widget tests for authentication screens (login, signup, role selection)**,
so that **critical user-facing auth UI is validated for correct rendering and user interaction handling**.

#### Acceptance Criteria

1. **Login screen widget tests**:
   - Email/password input field rendering
   - Login button tap triggering auth provider
   - Error message display for failed login
   - Loading state during authentication
   - Google/Apple sign-in button rendering
2. **Signup screen widget tests** for registration flow UI
3. **Role selection screen tests** for teacher/student role choice UI
4. **Auth error handling UI tests** for displaying error messages appropriately
5. **All widget tests pass** consistently without flakiness
6. **Mock AuthProvider** successfully injected via Provider test wrapper

#### Integration Verification

- **IV1**: Actual login screens continue functioning for users
- **IV2**: Auth error messages still display correctly
- **IV3**: OAuth buttons still trigger authentication flows
- **IV4**: Role selection after signup still works

### Story 1.9: Integration Tests for Critical User Flows

As a **developer**,
I want **integration tests for end-to-end critical user flows running against staging Firebase**,
so that **complete feature workflows are validated beyond unit/widget testing, catching integration issues**.

#### Acceptance Criteria

1. **Integration test suite** created in test/integration/ with staging Firebase configuration
2. **Auth flow integration test**: Complete login → dashboard navigation → logout flow
3. **Class management integration test**: Login as teacher → create class → enroll student → verify class appears
4. **Assignment flow integration test**: Create assignment → student login → submit assignment → teacher grades assignment
5. **Behavior points integration test**: Teacher assigns behavior point → student point total updates
6. **All integration tests pass** against staging environment
7. **Integration test execution time** <3 minutes for full suite
8. **Tests cleanup test data** after execution (no data pollution in staging)

#### Integration Verification

- **IV1**: Integration tests do NOT run against production (staging-only validation)
- **IV2**: Staging environment successfully supports integration test execution
- **IV3**: Integration test failures are distinct from unit/widget test failures (different test suites)

### Story 1.10: CI/CD Test Integration

As a **developer**,
I want **test execution integrated into GitHub Actions CI/CD pipeline with merge blocking**,
so that **no code can merge without passing tests, ensuring automated quality gates protect production**.

#### Acceptance Criteria

1. **GitHub Actions workflow updated** (.github/workflows/01_ci.yml):
   - Add unit test execution job (`flutter test test/unit/`)
   - Add widget test execution job (`flutter test test/widget/`)
   - Add test coverage generation (`flutter test --coverage`)
   - Add coverage validation (fail if <70% coverage)
2. **Pull request status checks** configured to block merge on:
   - Test failures (any test fails = no merge)
   - Coverage drop below 70% threshold
   - Lint failures (existing behavior preserved)
3. **Coverage report artifact** uploaded to GitHub Actions for PR review
4. **Test execution caching** optimized (Dart dependencies, Flutter SDK cached)
5. **CI test execution time** <5 minutes total (NFR1 compliance)

#### Integration Verification

- **IV1**: Existing CI workflow for linting and analysis continues working
- **IV2**: Existing web deployment workflow (02_deploy_web.yml) unaffected by test integration
- **IV3**: Manual merge still possible with appropriate permissions (admin override exists)
- **IV4**: PR developers receive clear test failure feedback in GitHub UI

### Story 1.11: Critical User Flow Documentation

As a **developer and future maintainer**,
I want **comprehensive documentation of 10+ critical user flows with step-by-step descriptions**,
so that **new developers understand expected behavior and have reference material for testing and debugging**.

#### Acceptance Criteria

1. **Documentation created** in docs/developer/user-flows/ for:
   - Teacher authentication flow (all auth methods)
   - Student authentication flow (all auth methods)
   - Class creation and management workflow
   - Student enrollment workflow
   - Assignment creation workflow
   - Assignment submission workflow
   - Grading workflow
   - Behavior points assignment workflow
   - Discussion board interaction workflow
   - Calendar event creation and sync workflow
2. **Each flow documented** with:
   - Step-by-step user actions
   - Expected system responses
   - Edge cases and error scenarios
   - Validation criteria for correct behavior
3. **Screenshots or diagrams** included where helpful (optional)
4. **Documentation integrated** with existing docs/ structure

#### Integration Verification

- **IV1**: Existing documentation (brownfield-architecture.md, Context.md) not duplicated or conflicted
- **IV2**: Documentation references match actual current application behavior
- **IV3**: New documentation discoverable via docs/developer/README.md

### Story 1.12: Incident Response Playbook

As a **developer and system operator**,
I want **documented incident response procedures including rollback, log analysis, and emergency contacts**,
so that **production issues can be resolved quickly with clear procedures and minimal downtime**.

#### Acceptance Criteria

1. **Incident response playbook** created in docs/developer/incident-response.md containing:
   - Rollback procedures (git revert commands, Firebase deployment rollback)
   - Firebase Console access and navigation guide
   - Log analysis procedures (LoggerService output, Firebase Functions logs, GitHub Actions logs)
   - Common incident scenarios and solutions (auth failures, Firestore rule changes, deployment issues)
   - Emergency contact information and escalation procedures
   - Staging environment validation procedures before production deploy
2. **Rollback procedures tested** in staging environment (simulate rollback, verify success)
3. **Documentation reviewed** by project owner for completeness

#### Integration Verification

- **IV1**: Rollback procedures can be executed without breaking production
- **IV2**: Log access procedures work with current Firebase Console and GitHub setup
- **IV3**: Documented emergency procedures are actionable and clear
