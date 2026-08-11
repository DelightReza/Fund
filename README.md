# 💰 Fund & Expense Tracker

A modern, fast, and feature-rich **Cross-Platform Group Fund & Expense Management** application built with **Flutter** and **Dart**.

It runs on both **Android** and **Web** using a single codebase. It uses a serverless, zero-database architecture powered by the **GitHub Contents API**, allowing you to store and synchronize your fund ledger (`data.json`) and configuration (`config.json`) directly in your own GitHub repository.

---

## ✨ Key Features

### 📊 **Dashboard & Analytics**
* **Real-time Overview**: Track total fund collections, total expenses, current balance, and individual member settlements.
* **Member Leaderboard & Status**: Instantly see who has paid, who owes money, or who is owed reimbursement.
* **Debt Simplification**: Automatically calculate the most efficient way to settle debts between members.

### 👤 **Member Profiles**
* Detailed breakdown per member showing their total contributions, incurred bills, and net balance.
* Filtered transaction history for individual members.

### ⚙️ **Admin Control Panel**
* **Transaction Management**: Record incoming contributions, bill payments, cash debt clearings, distributions, and transfers.
* **Offline Support & Sync**: On mobile, changes are queued offline and can be synchronized with GitHub when online.
* **Git Commit Reset Tool**: Revert remote GitHub commits directly from the UI when needed.

### 🔄 **GitHub Synchronization & Cross-Platform**
* **Mobile (Android)**: Connect to any GitHub repository using your Personal Access Token (PAT) for full admin capabilities and offline support.
* **Web**: Seamlessly runs read-only or with read/write if deployed directly from a GitHub repository using GitHub Pages, loading config and data dynamically.

### 🎨 **User Experience & Design**
* **Material 3 Design**: Clean, modern, and adaptive UI following Material 3 guidelines.
* **Dark / Light Theme**: Built-in dark mode support with automatic system preference detection.

---

## 🛠️ Tech Stack

* **Framework**: [Flutter](https://flutter.dev/) + [Dart](https://dart.dev/)
* **State Management**: [Riverpod](https://riverpod.dev/)
* **Networking**: `http` package
* **Storage**: `shared_preferences`

---

## 🚀 Getting Started

### Prerequisites
* **Flutter SDK**: `v3.24+`

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/<your-repo-name>.git
   cd <your-repo-name>
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app (Android or Web):**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```text
├── lib/
│   ├── main.dart             # Application entry point
│   ├── app.dart              # Main app widget and router
│   ├── models/               # Data models (Config, Transaction, etc.)
│   ├── providers/            # Riverpod state management and business logic
│   ├── screens/              # UI screens (Dashboard, Admin, Profile, etc.)
│   ├── services/             # API and local storage services (GitHub, Storage, Sync, Calculations)
│   ├── theme/                # Material 3 theme definitions
│   ├── utils/                # Helper utilities (Date, Format)
│   └── widgets/              # Reusable UI components
├── web/                      # Web specific files (index.html)
├── config.json               # Default configuration
├── data.json                 # Default fund ledger
└── pubspec.yaml              # Dependencies and configuration
```

---

## 🔧 Building for Production

### Android

To build an APK:
```bash
flutter build apk --release
```

To build an App Bundle (AAB):
```bash
flutter build appbundle --release
```

### Web

To build for the web:
```bash
flutter build web --release
```

---

## 📄 License

This project is open-source and available under the MIT License.
