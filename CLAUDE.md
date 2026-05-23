# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
cd /Users/apple/Work/Perapera
pod install                        # Install CocoaPods dependencies
open Perapera.xcworkspace          # Always use .xcworkspace, NOT .xcodeproj
```

Then Cmd+R in Xcode. iOS deployment target is 13.0. There are no unit tests, no SwiftLint, and no CI/CD configured.

Requires Xcode 15+ and a Tencent Cloud account with COS, ASR, and Hunyuan services enabled.

## Credentials (critical)

Two files are **gitignored** and must be set up locally:
- `Perapera/Services/COSConfig.local.swift` — COS bucket/region SecretId/SecretKey
- `Perapera/Services/HunyuanConfig.local.swift` — Hunyuan LLM SecretId/SecretKey

In DEBUG mode, credentials are loaded from these local files. In Release mode, they come from environment variables. All Tencent Cloud API calls use TC3-HMAC-SHA256 V3 signing.

## Architecture

**MVVM + Singleton Services**
- Views are SwiftUI `View` structs using `@StateObject` for ViewModels
- ViewModels are `ObservableObject` classes with `@Published` properties
- Every manager/service is a singleton: `SomeManager.shared` with `private init()`

**Networking**: Moya + RxSwift. The generic `NetWorkService<Target>` provides a reactive `MoyaProvider`. Extensions in `Observable+HandyJSON.swift` add `mapObject()` for decoding HandyJSON models from responses. Back-end base URL is `https://www.perapera.cc/api/v1/`.

### Core Pipeline (HomeView → VideoPlayerView)

The main user flow in `HomeView.swift` (~1359 lines) processes imported videos sequentially:
1. **Import** video (local file, Photos picker, or YouTube URL)
2. **Convert** to Opus audio via FFmpegKit (`AudioConverter.swift`)
3. **Upload** audio to Tencent COS (`COSUploadManager.swift`)
4. **Recognize** speech via ASR: CreateRecTask → poll DescribeTaskStatus (`ASRManager.swift`)
5. **Translate** ASR JSON to word-level translations with furigana/romaji via Hunyuan LLM (`HunyuanManager.swift`) — sent in batches, uses `_completingPipeline` flag to prevent duplicates
6. **Display** in `VideoPlayerView.swift` with word-level subtitle highlighting

### Key Managers

| Manager | File | Role |
|---------|------|------|
| `UserManager` | `Tools/UserManager.swift` | Auth state singleton, Combine `ObservableObject` |
| `LanguageManager` | `Tools/LanguageManager.swift` | UI language selector (19 languages) |
| `VideoStorageManager` | `Tools/VideoStorageManager.swift` | `VideoItem` model + CRUD (UserDefaults + Documents dir) |
| `SubtitleManager` | `Models/SubtitleModel.swift` | Subtitle parsing, active subtitle tracking, word timing |
| `HunyuanManager` | `Services/HunyuanManager.swift` | LLM translation with word-level output |

### Video Player (`Views/VideoPlayerView/`)

Local video: AVPlayer with word-level subtitle overlay. YouTube: WKWebView-based `YouTubePlayerView` bridged via `UIViewControllerRepresentable`. The `VideoPlayerViewModel` synchronizes subtitle display with playback time and handles both local + YouTube controllers via Combine sinks.

### Theme System (`Tools/Theme/`)

JSON-driven. `EXThemeColor.swift` loads color definitions from `EXThemeColorLight.json` / `EXThemeColorDark.json`. Colors are accessed via `Color.Ex.main`, `UIColor.Ex.text1`, etc. Supports light/dark/system modes.

### Local Storage

- **UserDefaults**: video list metadata (`saved_video_list`), subtitle data (`video_subtitles`), app settings
- **Documents dir**: `<id>.mp4`, `<id>.opus`, `<id>.json`, translation text files

## Code Origin

Portions of the networking layer and theme system were adapted from "coinup-bigclient-ios". Several references to this origin remain in comments.

## Currently Hidden/Disabled

Per recent commits, these features are hidden/commented out:
- Login UI (`LoginView`)
- "Join Perapera Pro" purchase flow
- Sync practice button on the player
- Speed control button on the player
- Pin button on the player
- Explain button on the player
- Home page popups and settings login entry points
