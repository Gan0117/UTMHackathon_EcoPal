# UTMHackathon_EcoPal
# 🌿 EcoPal — Natural Finance

> *Your money, your ecosystem. Spend wisely, grow naturally.*

EcoPal is a gamified personal finance app built with Flutter that turns your financial habits into a living, breathing garden. Instead of staring at dry charts, you tend to plants that grow or wilt based on how well you manage your money — with an AI-powered pet companion guiding you every step of the way.

---

## 🎯 Project Aim

Most budgeting apps fail because they feel like chores. EcoPal addresses this by making financial management **visual, emotional, and fun**. The core belief: if people can *see* the consequences of their spending habits reflected in something they care about — a thriving garden, a happy pet — they are more likely to build lasting, healthy financial behaviours.

EcoPal targets young adults and students who want to start managing their finances but find traditional tools intimidating or boring.

---

## ✨ Key Features

### 🌱 The Living Ledger (Dashboard Garden)
The home screen is a dynamic ecosystem that mirrors your financial health in real time.

- **Flora (Savings Pockets):** Each savings goal is represented as a plant. The more you save toward a target, the bigger and healthier the plant grows. You can have up to 5 money pockets simultaneously.
- **Weather System:** The garden's weather reflects your overall spending behaviour:
  - ☀️ **Sunny** — You are under budget. Plants grow faster.
  - ⛅ **Overcast** — Approaching your spending limit. Caution advised.
  - ⛈️ **Storming** — Over budget or in a debt trap. Plants begin to wilt.
- **Interactive Map:** Pan and zoom around your garden. Click on any plant to view or modify the details of that savings pocket.

### 🤖 AI-Powered Insights
Three AI modules powered by **Google Gemini** give you a 360° view of your financial behaviour.

- **Reality-Check Predictor:** Analyses your recent transaction history and forecasts your financial trajectory. It flags if you're on track to overspend next month and grades your habits as *Healthy*, *Moderate*, or *Unhealthy*.
- **Spending Behaviour Analysis:** Evaluates historical patterns across daily, monthly, and yearly timeframes. Displays a line chart of your spending alongside an AI-written suggestion.
- **AI Receipt Scanner:** Upload a photo or PDF of any receipt. Gemini Vision automatically extracts the merchant name, total amount, and spending category — no manual typing required.

### 📋 Receipt Keeper & Manual Entry
A dedicated scanner page where you can log every expense.

- Upload image (JPG/PNG) or PDF receipts for automatic extraction.
- Manual entry form with spend type, amount, and optional description.
- Confirmation dialog before any record is saved.
- Recent records list with a "View All" sheet that supports time and category filters.
- Each record gets an AI-assessed spending grade (*Healthy / Moderate / Unhealthy*) displayed inline.

### 💰 Money Pockets (Savings Goals)
Visual savings buckets tied to the garden plants.

- Create up to 5 pockets with a name, target amount, and starting balance.
- Auto Deduct feature: automatically channels a set amount from your Safe-to-Spend balance into a pocket on each transaction.
- Partial or full release: withdraw funds back to your main account at any time (full release deletes the pocket and returns all funds).
- Growth stages (small → medium → large plant) automatically calculated based on progress toward the target.

### 🪙 Habit Tax (Habit Tabung)
An automated micro-savings mechanism designed to make discretionary spending slightly painful — in a good way.

- Every time you log a transaction in a "guilty" category (Entertainment, Shopping, Guilty Pleasure), RM 1.00 is automatically deducted and deposited into a locked Habit Tabung.
- The Habit Tabung toggle can be enabled or disabled from the AI Insights page.
- Funds are **locked** until you maintain a *Healthy* spending grade, at which point a withdrawal button becomes available.

### 🐱 Pet Companion System
A virtual cat lives in your garden and reacts to your financial behaviour.

- Choose between two species at onboarding: **Tabby** (calm, observant) or **Orange** (playful, energetic).
- The pet has a hunger level and happiness level, both of which decay over time.
- **Feed** your pet by spending Reward Points (costs 50 points per feed). Feeding increases hunger EXP and can trigger a level-up.
- **Tap** your pet for free to increase happiness.
- The pet's GIF animation changes based on its current state: idle, happy, eating, or sleeping.
- A floating pet widget is accessible from every page, showing AI savings tips on tap.

### ⭐ Reward Points System
Healthy spending earns points that can be used to care for your pet.

| Spending Category | Points Earned |
|---|---|
| Food, Groceries, Utilities, Bills | +15 points |
| Other / Moderate categories | +5 points |
| Entertainment / Guilty Pleasure | +0 points |

### 👤 Profile & Social Sharing
- View your username, pet level, savings streak, and total harvest (combined balance across all accounts and pockets).
- Streak-based badge system: Bronze (default), Silver (7+ day streak), Gold (30+ day streak).
- **Share Progress:** Generate a shareable card showing your pet, level, streak, and total harvest to post on social media.
- Edit username in-app.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | FastAPI (Python) |
| Database & Auth | Supabase (PostgreSQL) |
| AI & Vision | Google Gemini 2.5 Flash |
| Charts | fl_chart |
| Animations | GIF assets via Procreate |

---

## 📱 Application Pages

| Page | Description |
|---|---|
| Login / Sign Up | Email/password and Google OAuth via Supabase Auth |
| Pet Selection | Choose and name your companion (Tabby or Orange) |
| Dashboard (Garden) | The main living ledger — plants, weather, navigation hub |
| Pet Room | Interact with, feed, and level up your pet |
| Receipt Scanner | Log spending via scan or manual entry; view records |
| AI Insights | Behaviour analysis, reality-check predictor, habit tax |
| Profile | Stats, streak, sharing, settings, logout |

---

## 🗄️ Database Schema (Supabase)

| Table | Key Columns |
|---|---|
| `profiles` | `id`, `username`, `safe_to_spend_balance`, `reward_points`, `streak` |
| `pets` | `user_id`, `name`, `species`, `level`, `hunger_level`, `happiness_level` |
| `pockets` | `user_id`, `name`, `target_amount`, `current_balance`, `growth_stage`, `is_locked`, `is_auto_deduct` |
| `transactions` | `user_id`, `amount`, `category`, `description`, `type`, `is_fixed`, `created_at` |
| `habit_tax` | `user_id`, `amount`, `available` |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x or later)
- Python 3.10+
- A Supabase project
- A Google Gemini API key

### Backend Setup

```bash
cd backend
pip install fastapi uvicorn supabase google-genai python-dotenv python-multipart
```

Create a `.env` file:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_API_KEY=your_supabase_service_key
GEMINI_API_KEY=your_gemini_api_key
```

Run the server:
```bash
uvicorn main:app --reload
```

### Frontend Setup

```bash
flutter pub get
flutter run
```

Update `lib/services/api_service.dart` to point `baseUrl` to your backend address.

---

## 👥 Team

Built for **UTM Hackathon** — a project exploring how gamification and AI can make personal finance accessible, engaging, and genuinely useful for young Malaysians.

---

## 📄 License

This project was created for hackathon purposes. All rights reserved by the team.
