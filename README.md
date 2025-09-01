# Fermi Monorepo

This monorepo contains:
- **apps/fermi**: The main Fermi Flutter application for education management
- **apps/docs**: Documentation for users and developers

## Structure

```
Fermi-Monorepo/
├── apps/
│   ├── fermi/          # Flutter education management app
│   └── docs/           # Mintlify documentation site
├── package.json        # Root workspace configuration
└── README.md          # This file
```

## Getting Started

### Fermi App
```bash
cd apps/fermi
flutter pub get
flutter run
```

### Documentation Site
```bash
cd apps/docs
mintlify dev
```
