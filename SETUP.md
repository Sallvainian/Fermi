# Fermi Monorepo Setup Guide

## Repository Structure
```
fermi-monorepo/
├── apps/
│   ├── fermi/          # Flutter education management app
│   └── docs/           # Mintlify documentation site
├── package.json        # Workspace configuration
└── README.md          # Project overview
```

## Quick Start

### Prerequisites
- Flutter SDK 3.24+
- Node.js 18+
- Firebase CLI
- Mintlify CLI

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Sallvainian/fermi-monorepo.git
   cd fermi-monorepo
   ```

2. **Install dependencies**
   ```bash
   # Install Node dependencies
   npm install
   
   # Install Flutter dependencies
   cd apps/fermi
   flutter pub get
   cd ../..
   ```

3. **Set up environment variables**
   ```bash
   # Copy the example env file in the Fermi app
   cp apps/fermi/.env.example apps/fermi/.env
   # Edit .env with your Firebase configuration
   ```

## Development

### Run the Flutter app
```bash
npm run dev:fermi
# or
cd apps/fermi && flutter run -d chrome
```

### Run the documentation site
```bash
npm run dev:docs
# or
cd apps/docs && mintlify dev
```

## Building for Production

### Build Flutter web app
```bash
npm run build:fermi
```

### Build documentation site
```bash
npm run build:docs
```

## Deployment

### Deploy Flutter app to Firebase Hosting
```bash
cd apps/fermi
flutter build web
firebase deploy --only hosting
```

### Deploy docs to Mintlify
```bash
cd apps/docs
mintlify deploy
```

## Working with Git Subtrees

This monorepo was created using git subtrees, preserving history from:
- Original Fermi app: `apps/fermi/`
- Original docs: `apps/docs/`

To pull updates from original repos (if needed):
```bash
git subtree pull --prefix=apps/fermi <original-fermi-repo> main
git subtree pull --prefix=apps/docs <original-docs-repo> main
```

## CI/CD Configuration

GitHub Actions workflows should be updated to:
1. Detect changes in specific apps
2. Run appropriate build/test commands
3. Deploy only affected applications

Example workflow structure:
```yaml
on:
  push:
    paths:
      - 'apps/fermi/**'
      - 'apps/docs/**'
```