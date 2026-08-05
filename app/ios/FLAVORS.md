# iOS flavors — pending Xcode setup

Android flavors are complete and verified. The iOS half of SPEC 02 step 4 is **not
done**: it needs Xcode, and the scaffolding was authored on Linux.

Everything that could be prepared without Xcode already is. What remains is the part
that lives inside the Xcode project file, where hand-editing is unsafe without being
able to open the project and confirm.

Budget: about 10 minutes of clicking.

## Target state

| Flavor    | Bundle identifier       | Display name    | Icon set          |
| --------- | ----------------------- | --------------- | ----------------- |
| `local`   | `com.dupla.app.local`   | `dupla local`   | `AppIcon-local`   |
| `staging` | `com.dupla.app.staging` | `dupla staging` | `AppIcon-staging` |
| `prod`    | `com.dupla.app`         | `dupla`         | `AppIcon-prod`    |

These values mirror Android exactly. Android is the reference — if the two ever
disagree, Android is right.

## Already done (no action needed)

- `IPHONEOS_DEPLOYMENT_TARGET = 15.0` across all build configurations.
- Base bundle identifier rewritten from `com.dupla.dupla` to `com.dupla.app`.
- Three asset catalogs generated with placeholder icons, opaque and alpha-free as
  the App Store requires: `Runner/Assets.xcassets/AppIcon-{local,staging,prod}.appiconset`.
  They are lettered `L`, `S`, `P` and colored to match the Android launcher icons.

## Remaining work

### 1. Create the build configurations

Open `Runner.xcodeproj`. In **Project → Runner → Info → Configurations**, duplicate
each existing configuration once per flavor:

| Duplicate | Into                                             |
| --------- | ------------------------------------------------ |
| `Debug`   | `Debug-local`, `Debug-staging`, `Debug-prod`     |
| `Release` | `Release-local`, `Release-staging`, `Release-prod` |
| `Profile` | `Profile-local`, `Profile-staging`, `Profile-prod` |

The names are not cosmetic. Flutter resolves `--flavor local` to the configuration
literally named `Debug-local`. A typo here surfaces as a confusing build failure.

Keep the original `Debug`, `Release` and `Profile`. Tooling that builds without a
flavor still needs them.

### 2. Set the per-flavor build settings

In **Target Runner → Build Settings**, expand each setting and fill in the nine
flavored configurations:

- **Product Bundle Identifier** → the value from the target-state table.
- **Asset Catalog App Icon Set Name** (`ASSETCATALOG_COMPILER_APPICON_NAME`) →
  `AppIcon-local`, `AppIcon-staging`, `AppIcon-prod`.

Then add a **user-defined setting** named `APP_DISPLAY_NAME`, and give it the display
name for each configuration. Set it on the base `Debug`/`Release`/`Profile` too, with
the value `dupla`, so flavorless builds keep a name.

Do the same for the **RunnerTests** target's bundle identifier, appending
`.RunnerTests` to each flavored identifier.

### 3. Point Info.plist at the display name

In `Runner/Info.plist`, change `CFBundleDisplayName` from the literal `Dupla` to:

```xml
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>
```

Do this **after** step 2. Introducing the variable before the setting exists leaves
the app with a blank name on the home screen.

### 4. Create the schemes

In **Product → Scheme → Manage Schemes**, create three schemes named exactly `local`,
`staging` and `prod`. Tick **Shared** on all three — an unshared scheme lives in your
personal Xcode data and never reaches the repository.

Map each scheme's actions to its configurations:

| Action  | Configuration      |
| ------- | ------------------ |
| Run     | `Debug-<flavor>`   |
| Test    | `Debug-<flavor>`   |
| Profile | `Profile-<flavor>` |
| Analyze | `Debug-<flavor>`   |
| Archive | `Release-<flavor>` |

Shared schemes are written to
`Runner.xcodeproj/xcshareddata/xcschemes/<name>.xcscheme`. Confirm the three files
appear there before committing.

## Verification

Run all three, then confirm the acceptance criterion — three apps installed side by
side, each distinguishable on the home screen:

```sh
fvm flutter run --flavor local
fvm flutter run --flavor staging
fvm flutter run --flavor prod
```

Then check identity from the built bundle, the iOS counterpart of the `aapt2` check
already run on the Android APKs:

```sh
fvm flutter build ios --flavor staging --no-codesign
plutil -p build/ios/iphoneos/Runner.app/Info.plist | grep -E 'CFBundleIdentifier|CFBundleDisplayName'
```

Expected: `com.dupla.app.staging` and `dupla staging`.

## Note on the Podfile

SPEC 02 step 3 mentions raising the iOS floor "in the Podfile". This project has no
Podfile: it was scaffolded on a Flutter version that uses Swift Package Manager for
plugins, visible as the `FlutterGeneratedPluginSwiftPackage` local package reference
in the project file. The iOS 15 floor therefore lives only in the Xcode build
settings, which is where it has been set. Nothing is missing — the spec's wording
predates the toolchain change.

Delete this file once the steps above are done and verified.
