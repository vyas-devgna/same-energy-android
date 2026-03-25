# Contributing to Same.Energy Android Client

Thank you for your interest in contributing! This guide will help you get started quickly and ensure a smooth collaboration process.

---

## 🚀 Getting Started

### 1. Fork & Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/same-energy-android.git
cd same-energy-android
```

### 2. Create a Branch

Use the following branch naming conventions:

| Prefix | Use Case | Example |
|--------|----------|---------|
| `feature/` | New features | `feature/camera-search` |
| `fix/` | Bug fixes | `fix/login-timeout` |
| `docs/` | Documentation changes | `docs/update-readme` |
| `chore/` | Maintenance tasks | `chore/update-deps` |
| `refactor/` | Code refactoring | `refactor/search-provider` |
| `test/` | Adding or updating tests | `test/auth-unit-tests` |

```bash
git checkout -b feature/your-feature-name
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
flutter run
```

---

## 📝 Commit Message Conventions

We follow the **[Conventional Commits](https://www.conventionalcommits.org/)** specification. Every commit message must follow this format:

```
<type>(<optional scope>): <short description>

<optional body>

<optional footer>
```

### Types

| Type | Description |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation-only changes |
| `style` | Code style changes (formatting, semicolons, etc.) |
| `refactor` | Code changes that neither fix a bug nor add a feature |
| `test` | Adding or correcting tests |
| `chore` | Maintenance tasks (build scripts, dependencies, CI) |
| `perf` | Performance improvements |
| `ci` | CI/CD configuration changes |

### Examples

```bash
feat(search): add camera-based visual search
fix(auth): resolve token refresh race condition
docs: update installation instructions in README
style: format files with dart format
refactor(api): extract response parsing into separate class
test(collections): add unit tests for bookmark provider
chore(deps): bump flutter_riverpod to 2.7.0
```

---

## 🛠️ Development Guidelines

### Code Style

- Follow the official **[Dart Style Guide](https://dart.dev/effective-dart/style)**
- Run the analyser before every commit:
  ```bash
  flutter analyze
  ```
- Format your code:
  ```bash
  dart format .
  ```
- All public APIs should have dartdoc comments

### Architecture

- Follow the established **Clean Architecture** pattern
- Use **Riverpod** for state management — no `setState` in feature screens
- Keep UI, domain, and data layers strictly separated
- Place reusable widgets in `lib/shared/widgets/`
- Place feature-specific code in `lib/features/<feature_name>/`

### Testing

Run the full test suite before submitting:

```bash
flutter test
```

- Write **unit tests** for providers and business logic
- Write **widget tests** for UI components
- Test on multiple screen sizes and Android API levels
- Ensure all existing tests still pass

---

## 🔀 Pull Request Process

1. **Ensure your branch is up to date** with `main`:
   ```bash
   git fetch origin
   git rebase origin/main
   ```
2. **Run all checks** locally:
   ```bash
   flutter analyze
   flutter test
   ```
3. **Push your branch** and open a Pull Request against `main`
4. **Fill out the PR template** completely
5. **Request a review** from a maintainer
6. **Address review feedback** promptly — push additional commits, do not force-push
7. Once approved, a maintainer will merge your PR 🎉

### PR Checklist

- [ ] Code follows the project style guide
- [ ] `flutter analyze` passes with no errors
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Documentation updated if applicable
- [ ] CHANGELOG.md updated under `[Unreleased]`
- [ ] No secrets, API keys, or credentials committed

---

## 🐛 Reporting Issues

When reporting a bug, please include:

- **Flutter version** (`flutter --version`)
- **Android version** and device model
- **Steps to reproduce** the issue
- **Expected vs actual behaviour**
- **Screenshots or logs** if applicable
- **Confirmation** that you searched existing issues first

Use the **Bug Report** issue template for the best experience.

---

## 💡 Feature Requests

For feature ideas:

1. **Search existing issues** to avoid duplicates
2. **Use the Feature Request** issue template
3. **Describe the problem** your feature would solve
4. **Propose a solution** with as much detail as possible
5. **Be open to discussion** — we may suggest alternative approaches

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the **MIT License** that covers this project.

---

<p align="center">Thank you for helping make Same.Energy Android Client better! 🙏</p>