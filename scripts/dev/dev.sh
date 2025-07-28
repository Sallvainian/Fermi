#!/bin/bash

# Flutter Development Helper Script
# Usage: ./scripts/dev.sh [command]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Show help
show_help() {
    echo "Flutter Development Helper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup       - Initial project setup"
    echo "  clean       - Clean and rebuild project"
    echo "  format      - Format all Dart files"
    echo "  analyze     - Run static analysis"
    echo "  test        - Run all tests"
    echo "  coverage    - Generate test coverage report"
    echo "  build       - Build for all platforms"
    echo "  run         - Run on available devices"
    echo "  doctor      - Check Flutter environment"
    echo "  upgrade     - Upgrade dependencies"
    echo "  pre-commit  - Run pre-commit checks"
    echo "  help        - Show this help"
}

# Initial setup
setup_project() {
    print_info "Setting up Flutter project..."
    
    # Check Flutter installation
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed!"
        exit 1
    fi
    
    # Get dependencies
    print_info "Getting dependencies..."
    flutter pub get
    
    # Setup git hooks
    if [ -f "scripts/setup-hooks.sh" ]; then
        print_info "Setting up Git hooks..."
        bash scripts/setup-hooks.sh
    fi
    
    # Create .env file if not exists
    if [ ! -f ".env" ]; then
        print_info "Creating .env file..."
        cat > .env << EOF
# Environment variables for local development
FIREBASE_PROJECT_ID=your-project-id
EOF
        print_warning "Please update .env file with your Firebase project ID"
    fi
    
    print_success "Project setup complete!"
}

# Clean project
clean_project() {
    print_info "Cleaning project..."
    flutter clean
    flutter pub get
    print_success "Project cleaned!"
}

# Format code
format_code() {
    print_info "Formatting Dart code..."
    dart format . --line-length=80
    print_success "Code formatted!"
}

# Analyze code
analyze_code() {
    print_info "Analyzing code..."
    flutter analyze --no-fatal-infos
    print_success "Analysis complete!"
}

# Run tests
run_tests() {
    print_info "Running tests..."
    flutter test
    print_success "Tests complete!"
}

# Generate coverage
generate_coverage() {
    print_info "Generating test coverage..."
    flutter test --coverage
    
    # Generate HTML report if lcov is installed
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        print_success "Coverage report generated at coverage/html/index.html"
    else
        print_warning "Install lcov to generate HTML coverage reports"
        print_success "Coverage data generated at coverage/lcov.info"
    fi
}

# Build for all platforms
build_all() {
    print_info "Building for all platforms..."
    
    # Android
    print_info "Building Android APK..."
    flutter build apk --release
    
    # Web
    print_info "Building Web..."
    flutter build web --release
    
    # iOS (only on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Building iOS..."
        flutter build ios --release --no-codesign
    fi
    
    print_success "Build complete!"
}

# Run on devices
run_app() {
    print_info "Checking available devices..."
    flutter devices
    
    echo ""
    read -p "Enter device ID (or press Enter for default): " device_id
    
    if [ -z "$device_id" ]; then
        flutter run
    else
        flutter run -d "$device_id"
    fi
}

# Flutter doctor
check_environment() {
    print_info "Checking Flutter environment..."
    flutter doctor -v
}

# Upgrade dependencies
upgrade_dependencies() {
    print_info "Upgrading dependencies..."
    flutter pub upgrade --major-versions
    print_success "Dependencies upgraded!"
}

# Pre-commit checks
pre_commit_checks() {
    print_info "Running pre-commit checks..."
    
    # Format check
    print_info "Checking formatting..."
    if ! dart format . --set-exit-if-changed; then
        print_error "Code is not properly formatted!"
        exit 1
    fi
    
    # Analyze
    print_info "Running analysis..."
    if ! flutter analyze --no-fatal-infos; then
        print_error "Analysis failed!"
        exit 1
    fi
    
    # Tests
    print_info "Running tests..."
    if ! flutter test; then
        print_error "Tests failed!"
        exit 1
    fi
    
    print_success "All pre-commit checks passed!"
}

# Main script logic
case "$1" in
    setup)
        setup_project
        ;;
    clean)
        clean_project
        ;;
    format)
        format_code
        ;;
    analyze)
        analyze_code
        ;;
    test)
        run_tests
        ;;
    coverage)
        generate_coverage
        ;;
    build)
        build_all
        ;;
    run)
        run_app
        ;;
    doctor)
        check_environment
        ;;
    upgrade)
        upgrade_dependencies
        ;;
    pre-commit)
        pre_commit_checks
        ;;
    help|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac