# Language Flashcards iOS

SwiftUI iPhone app for memorizing words and phrases across two languages.

## Features

- Multiple flashcard sets stored locally on device with SwiftData.
- Choose which language side is shown first.
- Tap to flip cards, auto-play pronunciation with optional mute.
- Scroll the flipped side to read long meanings and examples.
- Add cards manually or extract text from handwritten notes/photos with Vision OCR, then edit before saving.
- Swipe left/right between cards during a study session.
- Configurable session card count, defaulting to 10.
- Three-level memory rating: perfect, unsure, unknown.
- FSRS-lite spaced repetition that prioritizes cards by recall confidence, difficulty, and stability.
- Dashboard with today's counts, calendar marks, daily study trend, and improvement trend.
- Share a flashcard set as TXT, CSV, or PDF.
- Supabase email/password login.
- StoreKit premium subscription with Monthly and Yearly products.
- Adjustable text size and system/light/dark appearance setting.

## Supabase Setup

Create a Supabase project and enable Email/Password authentication. In the app, enter:

- Project URL, for example `https://xxxx.supabase.co`
- Anon public key

Do not put a service role key into the iPhone app.

## StoreKit Products

Create two auto-renewable subscriptions in App Store Connect and set a 1-week free introductory trial on both:

- `language_flashcards_premium_monthly`
- `language_flashcards_premium_yearly`

Purchases are linked to the logged-in Supabase user with StoreKit's app account token.

## Requirements

- Xcode 26 or later recommended
- iOS 17.0+

## Build

Open `LanguageFlashcards.xcodeproj` in Xcode and run the `LanguageFlashcards` scheme on an iPhone simulator or device.

## Real Device Check

1. Open `LanguageFlashcards.xcodeproj` in Xcode.
2. Connect your iPhone with USB or enable wireless debugging.
3. On the iPhone, enable Developer Mode if iOS asks for it.
4. In Xcode, select your iPhone as the run destination.
5. Confirm the app target uses Automatic Signing with Team `UYAG3JDD7G`.
6. Press Run.

If the device appears offline, unlock the iPhone, tap Trust This Computer, reconnect the cable, and restart Xcode if needed.
