# 💎 Fund & Expense Tracker

A production-grade, cross-platform **Group Fund, Shared Expense & Debt Simplification** application built with **Flutter**, designed specifically for **Web** and **Android**.

The application features a **100% Liquid Glass (Frosted Glassmorphism)** design system and operates on a **zero-database, serverless architecture** powered directly by the **GitHub REST API & GitHub Pages CDN**. Your group's configuration (`config.json`) and financial ledger (`data.json`) are stored with full version history in your own GitHub repository.

---

## ✨ Features & Capabilities

### 🎨 100% Liquid Glass Aesthetic
* **Multi-Color Ambient Aurora**: Dynamic fluid gradient meshes that smoothly transition across dark and light palettes.
* **Frosted Glass Surfaces**: Deep backdrop blur (`sigma: 16–24`), specular border highlights, and subtle translucency across all cards, dialogs, forms, and bottom navigation.
* **Floating Glass Island Navigation**: Compact, floating navigation capsule on mobile with responsive navigation rail support on wide screens.
* **Vibrant Fintech Palette**: Deep Emerald Green (`#047857`) for deposits, Electric Crimson (`#DC2626`) for expenses, Violet (`#7C3AED`) for settlements, and Indigo (`#312E81`) for total fund liquidity.

### 💳 Transaction Management & Split Engine
* **Transaction Types**:
  * **Quick Expense**: Automatically generates a paired Credit (who paid) + Debit (bill category) transaction with real-time fund balancing.
  * **Debit**: Direct expense drawn from the common fund.
  * **Credit**: Deposit or regular contribution added to the fund by a member.
  * **Distribute**: Equal disbursement of surplus fund credit among selected active participants.
  * **Settle Debt**: Direct balance settlement from debtor to creditor.
  * **Transfer**: Direct member-to-member balance transfer.
* **Equal & Custom Unequal Splits**:
  * Equal division across all participants with automatic 1-cent rounding adjustment.
  * Custom decimal amounts with real-time percentage allocation badges and validation.
* **Intelligent Duplicate Prevention**: Built-in 1-hour anti-collision safeguard that automatically detects and blocks identical duplicate transactions (matching amount, category, payer, and participants within a 60-minute window).
* **Visual Confirmation Dialogs**: Interactive pre-submission review showing payer, recipients, category, custom breakdown, and notes with specular frosted modals.

### 📊 Financial Ledger, Analytics & Debt Simplifier
* **Real-Time Fund Health**: Instant calculations of Total Fund Balance, Incurred Debits, Member Credits, and Month-over-Month surplus/deficit.
* **Member Ledger**: Real-time net balance calculations (Paid − Consumed = Net Balance) for every member.
* **Debt Simplification Graph**: Automatically computes the minimum number of transactions required to settle all debts across group members using an optimal greedy settlement algorithm.
* **Category Breakdown**: Aggregated expense totals with percentage progress indicators per category.
* **Monthly Filters**: Instant monthly filtering chips and category analytics.

### 🛡️ GitHub-Powered Serverless Backend & Offline-First Sync
* **Zero Database Overhead**: Your GitHub repository (`DelightReza/Fund`) acts as the permanent, auditable backend.
* **3-Way Conflict Resolution**: Detects remote commit SHA changes, fetches the latest remote state, preserves local pending changes, and re-applies non-conflicting transactions before committing.
* **Offline-First Persistence**: Cached locally via `shared_preferences`. If offline, transactions are queued and marked with a pending badge, automatically synchronizing as soon as connectivity is restored.
* **Commit History & Rollback**:
  * Inspect recent commits with author, message, and short SHA.
  * One-tap `Reset HEAD~1` quick undo or targeted hard reset to any previous commit via the GitHub Git Trees/Refs API.

### 🔐 Security & Access Control
* **Public & Private Repository Support**: Seamless read-only browsing for public funds; write actions (adding transactions, modifying config, rolling back commits) are gated behind an authenticated GitHub Personal Access Token (PAT) with `repo` scope.
* **Zero Secret Storage in Code**: Tokens are never committed or hardcoded. They are stored exclusively in client-side secure storage.

---

## 🛠️ Technology Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) 3.22+ / 3.47+ | Cross-platform targeting Web (HTML5/CanvasKit) & Android |
| **Language** | [Dart](https://dart.dev/) 3.3+ | Strong typing, null safety, structured async/await |
| **State Management** | [Provider](https://pub.dev/packages/provider) | Decoupled MVVM pattern with `ChangeNotifier` |
| **Data Layer** | [GitHub REST API v3](https://docs.github.com/rest) | Direct commit, branch ref, blob, and tree synchronization |
| **Local Cache** | [shared_preferences](https://pub.dev/packages/shared_preferences) | Offline-first ledger and configuration storage |
| **CI / CD** | [GitHub Actions](https://github.com/features/actions) | Automated GitHub Pages artifact build and deployment |

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `3.22.0` or higher)
* [Dart SDK](https://dart.dev/get-dart) (version `3.3.0` or higher)
* Chrome / Edge (for Web) or Android Studio / Device (for Android)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/DelightReza/Fund.git
   cd Fund
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run Locally:**
   * **Web:**
     ```bash
     flutter run -d chrome
     ```
   * **Android:**
     ```bash
     flutter run -d android
     ```

4. **Verify Code Quality:**
   ```bash
   flutter analyze
   ```

---

## 🌐 Production Web Deployment (GitHub Pages)

The project includes an automated GitHub Actions deployment workflow at `.github/workflows/deploy-web.yml`.

### Deployment Architecture
- Built with `--base-href /Fund/` to support repository subpaths.
- Automatically copies `config.json` and `data.json` into the root of `build/web/`.
- Deploys `404.html` (SPA routing fallback) to preserve deep links and bookmark routes.
- Uses the official `actions/upload-pages-artifact@v3` and `actions/deploy-pages@v4`.

### Enabling GitHub Pages in Your Repository
1. Navigate to your repository on GitHub: `https://github.com/DelightReza/Fund`
2. Go to **Settings** > **Pages**.
3. Under **Build and deployment** > **Source**, select **GitHub Actions**.
4. Any push to the `main` branch will automatically trigger the workflow and publish your site to:
   ```
   https://delightreza.github.io/Fund/
   ```

---

## 📱 Production Android Build

To compile release APKs or Android App Bundles (AAB) for Google Play or direct installation:

1. **Generate Release APK:**
   ```bash
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

2. **Generate Android App Bundle (AAB):**
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 📁 Project Directory Structure

```
.
├── .github/
│   └── workflows/
│       └── deploy-web.yml             # Automated GitHub Pages CI/CD workflow
├── lib/
│   ├── main.dart                      # App entry point, Provider configuration, AppRouter
│   ├── models/
│   │   ├── app_config.dart            # AppConfig, MemberConfig, BillTypeConfig models
│   │   ├── fund_data.dart             # FundData, BalanceEngine, settlements calculation
│   │   ├── github_models.dart         # GitHubCommit, GitHubRef, Tree models
│   │   └── transaction.dart           # TransactionModel (splits, exemptions, parents)
│   ├── repositories/
│   │   └── fund_repository.dart       # Workspace state, cache invalidation, 3-way merge sync
│   ├── screens/
│   │   ├── add_transaction_screen.dart# Transaction creation and custom split breakdown
│   │   ├── admin_screen.dart          # Admin control panel, sync modals, quick action grid
│   │   ├── category_expenses_screen.dart # Filtered expenses by category with month chips
│   │   ├── home_screen.dart           # Dashboard, Ledger, People, and Category tabs
│   │   ├── main_screen.dart           # Floating liquid glass navigation bar & shell
│   │   ├── manage_config_screen.dart  # People, bill types, and workspace config editor
│   │   ├── profile_screen.dart        # Member financial profile and personal timeline
│   │   ├── repo_selection_screen.dart # Multi-workspace repository switcher
│   │   ├── reset_commit_screen.dart   # Git commit inspector & rollback engine
│   │   ├── transaction_detail_screen.dart # Detailed split breakdown and edit/delete actions
│   │   └── user_selection_screen.dart # Profile selection for personal share calculation
│   ├── services/
│   │   ├── github_api_service.dart    # Direct GitHub REST API integration & raw content fallback
│   │   └── storage_service.dart       # SharedPreferences persistence and route state
│   ├── theme/
│   │   └── app_theme.dart             # Material 3 colors, gradients, and typography
│   ├── utils/
│   │   ├── app_router.dart            # Deep linking and cross-platform navigation helper
│   │   ├── date_utils.dart            # Date formatting and timeline helpers
│   │   ├── debt_simplifier.dart       # Greedy debt simplification engine
│   │   ├── format_utils.dart          # Currency formatting and percentage helpers
│   │   └── web_route_helper.dart      # Web URL synchronization & query param handling
│   └── widgets/
│       ├── admin/
│       │   ├── admin_action_card.dart         # Frosted glass admin quick action cards
│       │   └── admin_data_management_helper.dart # File upload, JSON parser, and 3-way merge import modal
│       ├── home/
│       │   └── transaction_filter_sheets.dart # Frosted bottom filter sheets (type, month, member, bill)
│       ├── transaction/
│       │   ├── custom_split_allocation_section.dart # Custom unequal split input grid with real-time badges
│       │   ├── transaction_date_time_picker.dart    # Cupertino/Material date & time picker trigger
│       │   └── transaction_form_selectors.dart      # Frosted participant selectors and bill category chips
│       ├── admin_pat_modal.dart       # Frosted glass GitHub PAT authentication modal
│       ├── confirmation_dialog.dart   # Transaction pre-flight review & animated success dialogs
│       ├── glass_container.dart       # Core Liquid Glass engine (AuroraBackground, GlassCard)
│       ├── settlement_card.dart       # Frosted glass debt settlement item
│       ├── summary_cards.dart         # Liquidity cards, member net balances, category totals
│       └── transaction_tile.dart      # Frosted glass transaction list items
├── config.json                        # Default repository configuration
├── data.json                          # Financial ledger database
└── pubspec.yaml                       # Flutter project dependencies and metadata
```

---

## 🔒 Security Best Practices

1. **Token Principle of Least Privilege**: When generating a GitHub Personal Access Token (PAT) for Admin actions, select only the **`repo`** (or Fine-grained: **`Contents: Read & Write`**) scope. Never grant administrative or billing permissions.
2. **Never Commit Tokens**: Tokens entered in the app are stored exclusively in the browser's or device's local private storage. They are never sent to external third parties or committed to git.
3. **Audit Trail**: Every update to `data.json` or `config.json` creates a standard Git commit with a detailed commit message, providing an immutable audit log of who made which change and when.

---

## 📄 License

This project is licensed under the **MIT License**.
