# StudentHub 🎓💳

> **Your Money. Your Future.**  
> A high-performance, privacy-first mobile companion engineered specifically for university students to master daily finances, track academic deadlines, and navigate campus dining.

---

## 🌟 Key Highlights & Features

- **⚡ Zero-Glitch Neo-Fintech UI:** Built on an Emerald Black (`#061412`) canvas with mint cyan accents, frosted glass cards (sigma 24 blur), and smooth rolling odometer number tickers.
- **💰 Smart Budgeting & Safe Buffer:** Real-time monthly allowance tracking with categorized outflows, receipt attachments, and retrospective month rollover archives.
- **🍽️ Campus Resto U Integration:** Direct synchronization with university dining services to monitor student card balance, transaction logs, and daily meal menus with secure session management.
- **📚 Academic Tasks & Checklist:** Filterable deadlines (Academic vs. Personal Chores), progress indicators, and persistent local storage.
- **🗓️ Timetable & Course Calendar:** Clean day/week academic timetable keeping critical assignment due dates in focus.
- **🏠 Shared Living & Utilities:** Split calculators for water, electricity, and internet bills, plus collaborative grocery checklists.
- **🌊 Floating Liquid Glass Dock:** Custom 5-tab responsive navigation dock with adaptive layout down to 280dp micro-viewports and dynamic line-art vector icons.

---

## 🛠️ Tech Stack & Architecture

- **Framework:** Flutter SDK `^3.5.0` (Dart 3)
- **State Management:** `Provider` (`ChangeNotifier`, reactive selectors)
- **Networking & Scraping:** `Dio`, `http`, and `html` parser with custom SSL certificate handler
- **Persistence & Security:** `shared_preferences` (unencrypted app state) & `flutter_secure_storage` (biometrics, PIN, session tokens)
- **Design System:** Custom vector painters (`HandHoldingCardPainter`, financial sparklines, radial gauges) & Google Fonts (`Plus Jakarta Sans`)
- **Architecture:** Feature-First Modular Architecture (see [ARCHITECTURE.md](ARCHITECTURE.md))

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.24.0 or newer)
- [Dart SDK](https://dart.dev/get-dart) (`^3.5.0`)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (API 21+) / Chrome for web testing

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/studenthold-app.git
   cd studenthold-app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify environment & static analysis:**
   ```bash
   flutter analyze
   ```

4. **Run test suites:**
   ```bash
   flutter test
   ```

5. **Launch the application:**
   ```bash
   # Run on connected mobile device or emulator
   flutter run

   # Or run in Chrome browser
   flutter run -d chrome
   ```

---

## 📂 Project Structure Preview

```text
lib/
├── core/                  # Theme tokens, custom vector painters & navigation dock
├── features/              # Feature-first domains:
│   ├── auth/              # Onboarding, profile state & vault gate
│   ├── home/              # Dashboard metrics, KPI cards & weekly rhythm
│   ├── expenses/          # Budget tracker, ledger & receipt modal
│   ├── tasks/             # Academic checklist & deadlines
│   ├── calendar/          # Class schedules & deadlines
│   ├── campus_resto/      # Dining portal scraper, auth & meal menus
│   └── utilities/         # Shared student bills & grocery checklist
├── controllers/           # Application-level Provider state controllers
├── models/                # Immutable data models
└── ui/                    # Presentation layer (views, sheets & navigation)
```

For complete architectural details, state flow diagrams, and design rules, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 🤝 Contribution & Quality Etiquette

1. **Branching Strategy:**
   - `main`: Production-ready release code.
   - `feat/<feature-name>`: New feature implementations.
   - `fix/<bug-name>`: Targeted bug fixes.

2. **Pre-Push Quality Gates:**
   Always run static analysis and unit tests before pushing or creating a pull request:
   ```bash
   flutter analyze && flutter test
   ```
   Ensure code is formatted according to standard Dart conventions:
   ```bash
   dart format lib test
   ```
