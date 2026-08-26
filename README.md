# 💰 Fund & Expense Tracker

A modern, cross-platform **Group Fund & Expense Management** application built with **Flutter**, supporting **Android**, **Web**, and **Desktop** platforms.

It uses a serverless, zero-database architecture powered by the **GitHub Contents API & Raw Content CDN**, allowing you to store, audit, and synchronize your fund ledger (`data.json`) and configuration (`config.json`) directly in your own GitHub repository.

---

## ✨ Key Features

### 📊 **Dashboard & Analytics**
* **Financial Overview**: Real-time summary of Total Fund Collections, Total Incurred Expenses, Net Fund Balance, and Active Member Count.
* **Member Ledger**: Clear breakdown of member contributions, incurred expense shares, net balances, and settlement recommendations.
* **Transaction Feed**: Comprehensive list of recent fund transactions with grouped expense badges, category icons, timestamps, and details.

### 💳 **Transaction Management**
* **Multiple Transaction Types**:
  * **Quick Expense**: Automatically handles paired Credit + Debit operations when a member pays for a shared bill.
  * **Debit**: Direct expense drawn from the fund balance.
  * **Credit**: Deposit or regular contribution added to the fund.
  * **Distribute**: Equal distribution of funds among selected active participants.
  * **Settle Debt / Transfer**: Direct balance transfers and debt settlements between members.
* **Dynamic Split & Exemptions**: Selectively include or exclude individual members from any expense or distribution.
* **Confirmation Modals**: Detailed summary review before committing any transaction.
* **Intelligent Edit Flow**: Automatically scrolls and focuses on selected bill types and members when editing existing entries.

### 📁 **Repository & Workspace Management**
* **Multi-Workspace Support**: Switch between multiple fund repositories with one tap.
* **Flexible Connection**: Connect using `owner/repo`, GitHub repository URLs, raw URLs, or GitHub Pages links.
* **Public & Private Repositories**: Works directly without tokens for public repos; securely supports GitHub Personal Access Tokens (PAT) for private repos.

### 👥 **Profiles & Categories**
* **Member Profiles**: Filtered history and individual financial statistics for each member.
* **Category Breakdown**: Group expenses by bill category (e.g., Food, WiFi, Utilities, Groceries).

### ⚙️ **Admin Controls**
* **Repository Configuration**: Manage members (add, activate/deactivate), bill categories, currency symbols, and site titles.
* **Commit History & Rollback**: View GitHub commit logs with SHA hashes and roll back invalid transactions or state changes.
* **Local Data Caching**: Offline-first storage with automatic cache invalidation and refresh.

### 🎨 **UI / UX Design**
* **Material Design 3**: Polished design system with responsive layouts for mobile and large screens.
* **Dark & Light Mode**: Manual theme switcher in the app bar alongside system preference matching.

---

## 🛠️ Tech Stack

* **Framework**: [Flutter](https://flutter.dev/) (Targeting Android, Web, and Desktop)
* **Language**: [Dart](https://dart.dev/)
* **State Management**: [Provider](https://pub.dev/packages/provider)
* **Local Persistence**: [shared_preferences](https://pub.dev/packages/shared_preferences)
* **HTTP & API**: [http](https://pub.dev/packages/http)
* **GitHub Backend**: GitHub REST API & GitHub Raw Content CDN

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: 3.22.0 or higher
* **Dart SDK**: 3.4.0 or higher
* **Android Studio / VS Code** with Flutter extensions

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

3. **Run the application:**
   * **Android:**
     ```bash
     flutter run
     ```
   * **Web:**
     ```bash
     flutter run -d chrome
     ```

4. **Build APK / Bundle:**
   ```bash
   flutter build apk --release
   flutter build appbundle --release
   ```

---

## 📁 Project Structure

```
├── lib/
│   ├── main.dart                      # App entry point and Provider setup
│   ├── models/                        # Data models (AppConfig, Transaction, GitHub models)
│   ├── repositories/                  # FundRepository & GitHub data coordination
│   ├── screens/                       # Flutter screens
│   │   ├── repo_selection_screen.dart # Workspace / repository selector
│   │   ├── user_selection_screen.dart # Active user switcher
│   │   ├── home_screen.dart           # Dashboard, ledger, and recent transactions
│   │   ├── add_transaction_screen.dart# Transaction creator and editor
│   │   ├── transaction_detail_screen.dart # Transaction inspection and paired view
│   │   ├── category_expenses_screen.dart  # Expenses filtered by category
│   │   ├── profile_screen.dart        # Member profile and personal transaction list
│   │   ├── admin_screen.dart          # Admin control panel and workspace settings
│   │   ├── manage_config_screen.dart  # Members and bill categories configuration
│   │   └── reset_commit_screen.dart   # GitHub commit rollback tool
│   ├── services/                      # GitHub API and SharedPreferences storage services
│   ├── theme/                         # Light and Dark Material 3 theme configurations
│   ├── utils/                         # Date, financial calculations, and string helpers
│   └── widgets/                       # Reusable UI components and confirmation dialogs
├── .github/workflows/                 # CI/CD workflows for automated builds and releases
└── pubspec.yaml                       # Flutter dependencies and metadata
```

---

## 📄 License

This project is open-source and available under the **MIT License**.
