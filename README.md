# Language Flashcards iOS

SwiftUI iPhone app for memorizing words and phrases across two languages.

## Features

- Multiple flashcard sets stored locally on device with SwiftData.
- Choose which language side is shown first.
- Tap to flip cards, auto-play pronunciation with optional mute.
- Scroll the flipped side to read long meanings and examples.
- Add cards manually or extract text from handwritten notes/photos with Vision OCR, then edit before saving.
- Complete missing meanings and examples with Gemini API.
- Swipe left/right between cards during a study session.
- Configurable session card count, defaulting to 10.
- Three-level memory rating: perfect, unsure, unknown.
- Simple spaced-repetition scheduling that increases uncertain cards and still reviews perfect cards later.
- Dashboard with today's counts, calendar marks, daily study trend, and improvement trend.
- Share a flashcard set as TXT or PDF.
- Adjustable text size and system/light/dark appearance setting.

## Gemini Setup

Open Settings in the app and paste your Gemini API key. The key is saved locally in Keychain and is not committed to GitHub.

The default Gemini model is `gemini-3.5-flash`, matching the current Gemini API text-generation examples. You can change the model name in Settings without changing app code.

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
