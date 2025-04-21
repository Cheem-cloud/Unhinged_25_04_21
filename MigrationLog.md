# Unhinged Project Migration Log

> **IMPORTANT: This document is the ONLY documentation allowed to exist in this project.**
> **All project knowledge and migration status must be recorded here.**
> **This document will be used to teach all future conversations about this project.**

## Table of Contents
1. [Project Overview](#project-overview)
2. [Migration Status](#migration-status)
3. [Project Structure](#project-structure)
4. [Dependencies](#dependencies)
5. [Migration Guidelines](#migration-guidelines)
6. [Troubleshooting](#troubleshooting)
7. [File Migration Log](#file-migration-log)

## Project Overview

Unhinged is the new name for the application previously known as CheemHang. This project is being migrated from a problematic structure to a clean Xcode project with proper dependency management through Xcode's package manager.

**Original Project**: CheemHang0303
**New Project**: Unhinged

### Core Functionality
- Social calendar application that facilitates hangouts and mutual availability scheduling
- Integration with multiple calendar providers (Google, Microsoft, Apple)
- Firebase backend for authentication, database, and storage
- Feature flag system for toggling features

## Migration Status

| Component | Status | Notes |
|-----------|--------|-------|
| Project Setup | Completed | New Xcode project created with directory structure |
| Configuration Files | Completed | Firebase configuration and Info.plist added |
| Resources | Completed | Fonts and assets copied |
| Models | Completed | All model files copied including referrals |
| Utilities | Completed | Merged Utilities and Utils folders |
| Services | Completed | Core services, adapters, and implementations copied |
| Firebase Integration | In Progress | GoogleService-Info.plist added |
| Authentication | Completed | Authentication feature copied |
| UI Components | Completed | Copied reusable UI components |
| Features | Completed | Copied Availability, Profile, Hangouts, Calendar features |
| ViewModels | Completed | ViewModels copied with features |
| Views | Completed | App views and navigation copied |
| App Entry | Completed | App delegate and main files copied |
| Tests | Not Started | |

## Project Structure

The new Unhinged project will use the following folder structure:

```
Unhinged/
├── App/ (App entry point, delegates, lifecycle)
│   └── Views/ (Main app views)
├── Models/ (Data models)
├── Services/ (Service layer)
│   ├── Core/ (Service protocols and base implementations)
│   ├── Implementations/ (Concrete service implementations)
│   │   ├── Calendar/ (Calendar service implementations)
│   │   └── Legacy/ (Original service implementations for migration)
│   └── Adapters/ (Adapters for legacy services during migration)
├── Features/ (Feature modules)
│   ├── Authentication/
│   ├── Calendar/
│   ├── Profile/
│   ├── Hangouts/
│   └── Availability/
├── Components/ (Reusable UI components)
├── Utilities/ (Helper functions and extensions)
├── Resources/ (Assets, fonts, etc.)
└── Configuration/ (Info.plist, configuration files)
```

## Dependencies

All dependencies will be managed through Xcode's package manager. The following packages are required:

| Package | Purpose | Version |
|---------|---------|---------|
| Firebase iOS SDK | Backend services | 10.15.0+ |
| GoogleSignIn | Authentication | 7.0.0+ |
| Kingfisher | Image loading/caching | 7.10.0+ |
| GoogleDataTransport | Analytics support | 9.0.0+ |

## Migration Guidelines

### Principles
1. **Incremental migration**: Move files in logical groups, test after each step
2. **Maintain functionality**: Ensure each component works before moving to the next
3. **Clean architecture**: Use the migration as an opportunity to improve architecture
4. **Documentation**: Update this document with each migration step

### Migration Process
1. **Create folder structure** in Unhinged matching the structure above
2. **Set up dependencies** through Xcode package manager
3. **Migrate files in this order**:
   a. Configuration files and resources
   b. Models and utilities (minimal dependencies)
   c. Service layer core protocols
   d. Service implementations
   e. Feature modules (one at a time)
   f. UI components
   g. App entry point and delegates

### Naming Conventions
- Keep original filenames when possible
- If renaming is necessary, use format: `[OriginalName]_migrated.swift`
- Document all renamed files in the migration log

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Duplicate file errors | Check for files with the same name in different folders |
| Missing dependencies | Ensure all packages are added through Xcode package manager |
| Build errors after migration | Check file target membership in Xcode |
| Firebase configuration issues | Verify GoogleService-Info.plist is included in the build |
| Storyboard/XIB errors | Check that IBOutlets and IBActions are properly connected |

## File Migration Log

| Status | Original File | New Location | Migration Step | Notes |
|--------|---------------|-------------|----------------|-------|
| Completed | - | - | Step 1 | Created folder structure |
| Completed | - | Configuration/GoogleService-Info.plist | Step 2 | Added new Firebase configuration file |
| Completed | CheemHang0303/Info.plist | Configuration/Info.plist | Step 3 | Copied Info.plist (will need bundle ID updates) |
| Completed | InterVariable.ttf | Resources/InterVariable.ttf | Step 3 | Copied font file |
| Completed | InterVariable-Italic.ttf | Resources/InterVariable-Italic.ttf | Step 3 | Copied font file |
| Completed | CheemHang0303/Assets.xcassets | Unhinged/Assets.xcassets | Step 3 | Copied assets |
| Completed | CheemHang/Models/*.swift | Models/*.swift | Step 4 | Copied model files |
| Completed | CheemHang/Models/Referrals/*.swift | Models/Referrals/*.swift | Step 4 | Copied referral model files |
| Completed | CheemHang/Utilities/*.swift | Utilities/*.swift | Step 4 | Copied utility files |
| Completed | CheemHang/Utils/*.swift | Utilities/*.swift | Step 4 | Copied additional utility files (merged with Utilities) |
| Completed | CheemHang/Services/Core/*.swift | Services/Core/*.swift | Step 5 | Copied core service protocols and implementations |
| Completed | CheemHang/Services/Adapters/*.swift | Services/Adapters/*.swift | Step 5 | Copied service adapters |
| Completed | CheemHang/Services/Calendar/*.swift | Services/Implementations/Calendar/*.swift | Step 5 | Copied calendar service files |
| Completed | CheemHang/Services/Calendar/Protocols/*.swift | Services/Implementations/Calendar/Protocols/*.swift | Step 5 | Copied calendar service protocols |
| Completed | CheemHang/Services/Calendar/Providers/*.swift | Services/Implementations/Calendar/Providers/*.swift | Step 5 | Copied calendar providers |
| Completed | CheemHang/Services/*.swift | Services/Implementations/Legacy/*.swift | Step 5 | Copied legacy service files |
| Completed | CheemHang/Features/Availability/*.swift | Features/Availability/*.swift | Step 6 | Copied Availability feature |
| Completed | CheemHang/Features/Profile/*.swift | Features/Profile/*.swift | Step 6 | Copied Profile feature |
| Completed | CheemHang/Features/Hangouts/*.swift | Features/Hangouts/*.swift | Step 6 | Copied Hangouts feature |
| Completed | CheemHang/Features/Calendar/*.swift | Features/Calendar/*.swift | Step 6 | Copied Calendar feature |
| Completed | CheemHang/Authentication/*.swift | Features/Authentication/*.swift | Step 6 | Copied Authentication feature |
| Completed | CheemHang/Components/*.swift | Components/*.swift | Step 6 | Copied UI Components |
| Completed | CheemHang/Components/DatePickers/* | Components/DatePickers/* | Step 6 | Copied DatePickers components |
| Completed | CheemHang/App/*.swift | App/*.swift | Step 6 | Copied App delegate and main files |
| Completed | CheemHang/App/Views/* | App/Views/* | Step 6 | Copied App views |

---

**Migration Steps**

1. **Step 1**: Project setup & initial documentation
   - Created new Xcode project "Unhinged"
   - Created this migration log document
   - Created folder structure for organized code

2. **Step 2**: Configuration setup
   - Added new GoogleService-Info.plist from Firebase Console for the Unhinged app

3. **Step 3**: Resources setup
   - Copied Info.plist to Configuration folder (will need bundle ID updates)
   - Copied font files to Resources folder
   - Copied assets to Assets.xcassets

4. **Step 4**: Models and Utilities setup
   - Copied model files to Models folder
   - Created Models/Referrals subdirectory for referral models
   - Copied utility files to Utilities folder
   - Merged Utils and Utilities folders to consolidate utility files

5. **Step 5**: Services layer setup
   - Copied core service protocols and base implementations
   - Copied service adapters
   - Created organized structure for calendar service implementations
   - Preserved legacy services in a separate folder for gradual migration

6. **Step 6**: Features, components, and app files
   - Copied major feature modules (Availability, Profile, Hangouts, Calendar)
   - Copied Authentication feature to Features/Authentication
   - Copied UI components including DatePickers
   - Copied app delegate and main app files
   - Copied app views structure

---

**Current Status**: All code files have been migrated. Next steps are to add package dependencies in Xcode and ensure proper target membership of files, followed by updating file references, namespaces, imports, and bundle IDs. 