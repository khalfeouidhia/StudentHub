# StudentHub Mobile Application Architecture

## 1. High-Level Architectural Overview

StudentHub is architected around **Feature-First Domain Modularity** paired with **Layered Clean Architecture**. The application is structured into decoupled functional domains, backed by reactive in-memory and persistent state controllers, unified storage abstractions, and a strict design system.

### Core Architectural Pillars
- **Feature-First Organization:** Business capabilities (`campus_resto`, `home`, `expenses`, `tasks`, `calendar`, `utilities`, `auth`) are packaged with domain boundaries, exposing clean barrel interfaces.
- **Reactive State Management:** State is governed using `ChangeNotifier` and `Provider` (with selector and consumer scoping), avoiding bloated monolithic controllers.
- **Two-Tier Persistence:** Unsensitive user preferences, cached menus, and budget transactions are stored in `SharedPreferences`, while authentication credentials and campus session tokens are stored in hardware-backed `FlutterSecureStorage`.
- **Locked UI & Visual Protection:** Visual tokens, gradients, and layout assertions are isolated within `core/theme/` and `ui/`, guaranteeing design consistency without accidental layout regressions.

---

## 2. Directory Map

```text
studenthold-app/
├── android/                        # Native Android host configuration, splash configs & manifest
├── assets/
│   ├── icon/
│   │   └── app_logo.png            # Adaptive app launcher icon
│   └── images/
│       └── header_avatar.png       # 3D student character illustration for dashboard hero
├── lib/
│   ├── main.dart                   # Application entrypoint, provider tree bootstrap & HTTP overrides
│   ├── core/                       # Foundational primitives, theme, shared widgets & navigation
│   │   ├── core.dart               # Core domain barrel export
│   │   ├── theme/
│   │   │   └── app_colors.dart     # Emerald Black, Mint, Moss & Frosted Glass color constants
│   │   └── widgets/
│   │       ├── frosted_glass_card.dart     # BackdropFilter frosted card primitive (sigma 18-24)
│   │       ├── roulette_number_text.dart   # Animated rolling odometer typography widget
│   │       ├── financial_painters.dart     # Sparkline, donut and radial gauge custom painters
│   │       └── hand_holding_card_icon.dart # Custom line-art vector icon for payments/expenses
│   ├── features/                   # Feature-driven business domains
│   │   ├── auth/
│   │   │   └── auth.dart           # Onboarding, profile state & vault gate barrel
│   │   ├── home/
│   │   │   ├── home.dart           # Home view, metrics & rhythm barrel
│   │   │   └── widgets/            # Hero typewriter header & glass KPI cards
│   │   ├── expenses/
│   │   │   └── expenses.dart       # Expenses view, budget tracker, receipt sheet & models
│   │   ├── tasks/
│   │   │   └── tasks.dart          # Tasks view, filterable deadlines & chore models
│   │   ├── calendar/
│   │   │   └── calendar.dart       # Academic timetable & calendar views
│   │   ├── campus_resto/           # University dining integration (Scraper, Dio, Auth & Views)
│   │   │   ├── controllers/        # CampusRestoController managing live saldo & meal menus
│   │   │   ├── models/             # Meal item, student profile, wallet KPIs & session cookies
│   │   │   ├── services/           # HTTP/Dio client, HTML scraping parser, secure storage
│   │   │   └── ui/                 # RestoUView, history sheets & meal detail dialogs
│   │   └── utilities/
│   │       └── utilities.dart      # Shared flat bills, groceries & split invoice calculators
│   ├── controllers/                # App-level state management controllers (Provider)
│   │   ├── auth_controller.dart            # User profile, safe buffer, university & PIN
│   │   ├── budget_controller.dart          # Transaction records, monthly caps & month rollover
│   │   ├── home_controller.dart            # Quick actions & dashboard summary aggregation
│   │   ├── tasks_controller.dart           # Academic & personal deadlines with persistence
│   │   ├── user_profile_controller.dart    # User profile preferences bridge
│   │   └── utilities_controller.dart       # Apartment utility bills & grocery checklist
│   ├── models/                     # Shared immutable data models
│   │   ├── chore.dart                      # Academic/personal task model
│   │   ├── expense_item.dart               # Expense record model with category tags
│   │   └── monthly_summary_report.dart     # Retrospective archive report for past months
│   ├── services/                   # App-wide storage and infrastructure services
│   │   └── storage_service.dart            # SharedPreferences interface wrapper
│   └── ui/                         # Finalized presentation layer
│       ├── navigation/
│       │   ├── bottom_nav_bar.dart         # Standard BottomNavigationBar with custom vector
│       │   ├── liquid_glass_nav_bar.dart   # 5-tab floating liquid glass dock with frosted blur
│       │   └── main_shell.dart             # Primary scaffold shell hosting IndexedStack
│       ├── sheets/
│       │   └── payly_sheets.dart           # Bottom sheet modals for expenses and tasks
│       ├── views/                          # Screen views (Home, Expenses, Tasks, etc.)
│       └── widgets/                        # Presentation painters & vector icons
└── test/                           # 60+ test suites: unit, widget, edge-case & adversarial tests
    ├── core/                       # Theme & vault unit tests
    ├── features/campus_resto/      # Dining parser, session storage & UI stress tests
    ├── navigation/                 # 5-tab dock layout & custom vector tests
    ├── views/                      # Screen layout & interaction tests
    └── widgets/                    # Gauge, sparkline, roulette number & glass tests
```

---

## 3. State Management & Data Flow

```text
[ User Action / UI Trigger ]
            │
            ▼
┌─────────────────────────┐
│     View / Sheet UI     │ ◄─── (Listens via Provider context.watch / Consumer)
└───────────┬─────────────┘
            │ calls methods
            ▼
┌─────────────────────────┐
│ State Controller        │ (e.g. BudgetController, TasksController, CampusRestoController)
│ - Mutates in-memory data│
│ - Calculates KPI metrics│
│ - Calls notifyListeners ├────────┐
└───────────┬─────────────┘        │
            │                      ▼
            │ calls save    [ Reactive UI Re-render ]
            ▼
┌─────────────────────────┐
│ Storage / Network Layer │
│ - SharedPreferences     │ (Local JSON records, caps, profile)
│ - FlutterSecureStorage  │ (PIN, session cookies)
│ - Dio / HTTP Scraper    │ (Campus portal web service)
└─────────────────────────┘
```

1. **User Interaction:** User initiates an action (e.g. logging an expense, adding a task, refreshing campus saldo).
2. **Controller Dispatch:** The view invokes the corresponding controller method (e.g. `BudgetController.addExpense()`).
3. **State Mutation & Sanitization:** Controller validates input (e.g. non-finite number clamping, date sanitation), mutates its internal state, and invokes `notifyListeners()`.
4. **Reactive Update:** All dependent widgets listening via `Provider.of`, `context.watch`, or `Consumer` re-render efficiently.
5. **Asynchronous Persistence:** Changes are serialized to `SharedPreferences` or `FlutterSecureStorage` asynchronously in the background.

---

## 4. Design System & Theming

The application follows an **Emerald Neo-Fintech Glassmorphism** design language.

### Color Palette (`lib/core/theme/app_colors.dart`)
- **Dark Emerald Base:** `#061412` / `#071F18` (deep, focused background preventing battery drain and eye strain).
- **Vibrant Mint & Cyan:** `#00E5BE` / `#00E676` (high-contrast active state indicators and success markers).
- **Moss & Forest Green:** `#1E3A2E` / `#264A3B` / `#16A34A` (secondary cards, badges, and progress tracks).
- **Soft Sage & Slate Teal:** `#7A9B93` / `#A3B899` (readable unselected labels, secondary metadata).
- **Frosted Specular Glass:** `rgba(255, 255, 255, 0.85)` borders with `BackdropFilter` sigma `18`–`24`.

### Custom Vector Line Art
- Custom vector art (such as [`HandHoldingCardIcon`](lib/ui/widgets/hand_holding_card_icon.dart)) is implemented via native Flutter `CustomPainter`, avoiding heavy external SVG renderer dependencies and ensuring crisp scaling at any DPI.
- Icons dynamically inherit `IconTheme.of(context).color`, matching active/inactive dock states automatically.
