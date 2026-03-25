# Same.Energy Android Documentation

Welcome to the documentation folder! This contains technical guides and architectural deep-dives for contributors.

## 🚀 Getting Started
Refer to the `README.md` at the project root for basic installation instructions. 
If diagnosing issues, check out our `CONTRIBUTING.md` guide.

## 🏗️ Architecture Deep Dive
The application relies on **Riverpod** for robust, testable state management and **GoRouter** for declarative navigation. 
Our layer separation is strictly maintained:
1. **Core**: Telemetry, Design Tokens, API clients, Data Models.
2. **Features**: UI, State Providers, Local logic for bounded features (Collections, Search, Profile).
3. **Shared Widgets**: Reusable stateless/stateful UI components.

## 🔌 API Integration Notes
We communicate with the public same.energy APIs via `Dio` and specific configuration interceptors (adding origin and custom accept-times). 

Happy coding!
