# Localization Analysis for Immich-AppleTV

## Current State

### ✅ What's Configured

1. **Project Settings (Xcode)**
   - `developmentRegion = en` (line 317 in project.pbxproj)
   - `knownRegions = (en, Base)` (lines 319-322)
   - `LOCALIZATION_PREFERS_STRING_CATALOGS = YES` (lines 473, 532) ✅ **Modern String Catalog support enabled**
   - `STRING_CATALOG_GENERATE_SYMBOLS = YES` (lines 478, 536)
   - `SWIFT_EMIT_LOC_STRINGS = YES` (lines 569, 601) ✅ **Localization string extraction enabled**

2. **System-Level Localization**
   - Uses `.localizedDescription` for error messages (system-provided localization)
   - Uses `.localizedCaseInsensitiveCompare()` for string sorting (respects locale)

### ❌ What's Missing

1. **No Localization Files**
   - No `.lproj` folders found
   - No `.strings` files found
   - No `.xcstrings` (String Catalog) files found

2. **Hardcoded Strings**
   - All UI text is hardcoded in English throughout the codebase
   - Examples found:
     - `"Oops! Unexpected Error"` (UniversalErrorHandler.swift:23)
     - `"Server URL"`, `"Email"`, `"Password"` (SignInView.swift)
     - `"Search Your Photos"`, `"No Results Found"` (SearchView.swift)
     - `"Show Tags Tab"`, `"Show Albums Tab"` (SettingsView.swift)
     - And many more...

3. **No Localization API Usage**
   - No `NSLocalizedString()` calls found
   - No `String(localized:)` calls found (SwiftUI modern approach)
   - No `Text(localized:)` usage

4. **Hardcoded Locale/Language Settings**
   - **SearchService.swift:16**: `"language": "en-CA"` - Hardcoded for API calls
   - **DateFormatter+Extensions.swift:35**: `Locale(identifier: "en_US_POSIX")` - Hardcoded for date parsing

5. **No Locale Detection**
   - No code using `Locale.current` or `Locale.autoupdatingCurrent`
   - No code accessing `Locale.preferredLanguages`
   - No mechanism to detect device language/region

---

## How Auto-Detection Works in iOS/tvOS

### Automatic Language Detection

iOS/tvOS **automatically** detects the user's preferred language from:
1. **System Settings** → **General** → **Language & Region**
2. The app's `Info.plist` `CFBundleLocalizations` array (which languages the app supports)
3. The user's preferred language order

### How It Works

1. **At Runtime:**
   - `Locale.current` returns the user's current locale
   - `Locale.preferredLanguages` returns the user's preferred language list
   - `Bundle.main.preferredLocalizations` returns the app's best matching localizations

2. **For Localized Strings:**
   - When you use `NSLocalizedString("key", comment: "")` or `String(localized: String.LocalizationValue("key"))`
   - iOS automatically looks for the string in:
     - `en.lproj/Localizable.strings` (if user's language is English)
     - `de.lproj/Localizable.strings` (if user's language is German)
     - Falls back to `Base.lproj` or development region if not found

3. **For String Catalogs (Modern Approach):**
   - Xcode 15+ uses `.xcstrings` files
   - One file contains all languages
   - Auto-generates localization files during build
   - Better tooling and validation

---

## Implementation Strategy

### Phase 1: Setup String Catalog

1. **Create String Catalog:**
   ```bash
   # In Xcode: File → New → File → String Catalog
   # Or manually create: Localizable.xcstrings
   ```

2. **Add to Project:**
   - Add `Localizable.xcstrings` to the project
   - Ensure it's included in the app target

### Phase 2: Replace Hardcoded Strings

**Modern SwiftUI Approach (Recommended):**
```swift
// Instead of:
Text("Search Your Photos")

// Use:
Text("Search Your Photos", bundle: .main, comment: "Search screen title")
// Or with key:
Text("search.title", bundle: .main)
```

**Or using String extension:**
```swift
// Instead of:
"Server URL"

// Use:
String(localized: "server.url", defaultValue: "Server URL")
```

### Phase 3: Auto-Detect Locale for API Calls

**Update SearchService.swift:**
```swift
func searchAssets(query: String, page: Int = 1) async throws -> SearchResult {
    // Auto-detect language from device
    let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
    let regionCode = Locale.current.region?.identifier ?? "US"
    let languageTag = "\(languageCode)-\(regionCode)"
    
    let searchRequest: [String: Any] = [
        "page": page,
        "withExif": true,
        "isVisible": true,
        "language": languageTag,  // Auto-detected
        "query": query
    ]
    // ...
}
```

### Phase 4: Auto-Detect Locale for Date Formatting

**Update DateFormatter+Extensions.swift:**
```swift
// For parsing (keep POSIX for consistency):
outputFormatter.locale = Locale(identifier: "en_US_POSIX")

// For display (use user's locale):
let displayFormatter = DateFormatter()
displayFormatter.locale = Locale.current  // Auto-detected
displayFormatter.dateStyle = .medium
displayFormatter.timeStyle = .short
```

---

## Files That Need Localization

### High Priority (User-Facing)

1. **SignInView.swift**
   - "Server URL", "Email", "Password", "API Key"
   - "Welcome Back", "Sign in to continue"
   - "Add Account", "Connect another Immich server"
   - Button labels and error messages

2. **SearchView.swift**
   - "Search Your Photos"
   - "No Results Found"
   - "Try different search terms"
   - "Error", "Retry"

3. **SettingsView.swift**
   - "Show Tags Tab", "Show Albums Tab", "Show Folders Tab"
   - All settings labels and descriptions

4. **UniversalErrorHandler.swift**
   - "Oops! Unexpected Error"
   - Error descriptions

5. **SignInViewModel.swift**
   - All computed property strings (headerTitle, headerSubtitle, etc.)

### Medium Priority

- **ExploreView.swift** - Navigation and labels
- **StatsView.swift** - Statistics labels
- **FullScreenImageView.swift** - UI labels
- **All other View files** - Any user-visible text

### Low Priority (System Messages)

- Error messages from APIs (already use `.localizedDescription`)
- Technical info overlays

---

## Recommended Implementation Steps

### Step 1: Create String Catalog
1. In Xcode: `File → New → File → Resource → String Catalog`
2. Name it `Localizable.xcstrings`
3. Add to project target

### Step 2: Extract Strings (Semi-Automated)
1. Use Xcode's built-in extraction:
   - Select a hardcoded string
   - Right-click → "Extract to String Catalog"
2. Or manually add keys to the catalog

### Step 3: Update Code to Use Localized Strings
1. Replace hardcoded strings with `String(localized:)` or `Text(localized:)`
2. Use descriptive keys: `"signin.server.url"` instead of `"Server URL"`

### Step 4: Add Locale Detection
1. Create a helper for API language detection
2. Update SearchService to use auto-detected locale
3. Update date formatters where appropriate

### Step 5: Add Additional Languages
1. In String Catalog, click "+" to add languages
2. Translate strings for each language
3. Test with different system languages

---

## Example Implementation

### Before:
```swift
Text("Search Your Photos")
    .font(.title)
```

### After:
```swift
Text("search.title", bundle: .main, defaultValue: "Search Your Photos")
    .font(.title)
```

### Locale Detection Helper:
```swift
extension Locale {
    static var apiLanguageTag: String {
        let languageCode = current.language.languageCode?.identifier ?? "en"
        let regionCode = current.region?.identifier ?? "US"
        return "\(languageCode)-\(regionCode)"
    }
}

// Usage:
"language": Locale.apiLanguageTag
```

---

## Testing Localization

1. **In Simulator/Device:**
   - Settings → General → Language & Region
   - Change language
   - Restart app

2. **In Xcode:**
   - Edit Scheme → Run → Options
   - Change "Application Language"

3. **Verify:**
   - All strings should appear in the selected language
   - API calls should use correct language tag
   - Dates should format according to locale

---

## Summary

**Current Status:** ❌ **Not Localized**
- Project is configured for localization but not implemented
- All strings are hardcoded in English
- No locale detection for API calls or date formatting

**Auto-Detection:** ✅ **Works Automatically Once Implemented**
- iOS/tvOS automatically detects user's language
- No manual detection code needed for UI strings
- Only need to detect locale for API calls and date formatting

**Next Steps:**
1. Create `Localizable.xcstrings` String Catalog
2. Replace hardcoded strings with localized versions
3. Add locale detection for API calls
4. Test with different languages

