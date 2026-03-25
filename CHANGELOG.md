# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- No upcoming features mapped yet.

## [1.0.0] - 2026-03-25

### Added
- Complete open-source release of the Same.Energy Android Client.
- Intelligent search capabilities: Visual Search, Text Search, Hybrid Search, and Safe Search.
- Premium UI experience featuring Glassmorphism design and beautiful micro-animations.
- Curated content feeds (Paintings, Nature, Architecture, etc.).
- Image Collections and Bookmarks functionality requiring user authentication.
- Full-screen Image Viewer with similar image recommendations.
- Robust offline support with structured local data caching.
- Deep linking support that seamlessly opens same.energy URLs inside the app.
- Clickstream telemetry integration fully aligned with the web platform.
- Clean Architecture implementation using Riverpod for dynamic state management, GoRouter for routing, and Dio for networking.

### Changed
- Extensive documentation added for open-source contributors (README, CONTRIBUTING, CODE_OF_CONDUCT).
- GitHub issue templates and CI/CD configuration added for automation.

### Security
- Integrated `flutter_secure_storage` for token and credential encryption.
- PIN-based Collection lock implementation for private boards.