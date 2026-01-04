# CloudKit Best Practices for SwiftData

Quick reference based on real debugging experience with Summa app.

> **Source**: Lessons learned debugging macOS CloudKit sync issues and [grtnr.com/SwiftData-on-iCloud](https://grtnr.com)

## Xcode Capabilities Setup

Before code changes, add these in Xcode (Project → Target → Signing & Capabilities):

1. **iCloud capability**
   - Click + Capability → iCloud
   - Enable CloudKit service
   - Create container: `iCloud.com.yourcompany.YourApp`
   - Wait for red → black (container created on server)

2. **Background Modes capability**
   - Click + Capability → Background Modes
   - Enable "Remote notifications"
   - Required for CloudKit change notifications

## Essential Configuration

### 1. Enable CloudKit Sync
```swift
// SummaApp.swift - ModelConfiguration
let config = ModelConfiguration(
    url: storeURL,
    cloudKitDatabase: .private("iCloud.com.grtnr.Summa")
)
```
**Without this**: Local-only storage, no sync.

### 2. macOS Sandbox Networking
```xml
<!-- SummaDebug.entitlements -->
<key>com.apple.security.network.client</key>
<true/>
```
**Without this**: macOS CloudKit setup fails silently.

### 3. Background Modes
```xml
<!-- Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```
**Without this**: No remote sync notifications.

## Data Model Rules

### CloudKit Compatibility
- ✅ All relationships must be **optional** (`Series?` not `Series`)
- ✅ All fields should have default values
- ❌ No unique constraints
- ❌ No ordered relationships

### Storage Attributes
- **Avoid** `@Attribute(.externalStorage)` if possible
- CloudKit cannot auto-migrate between external ↔ inline storage
- Store images inline for small data (<1MB)
- Use external storage only for truly large assets

## Sync Behavior

### When Exports Happen
- App backgrounding (iOS/iPadOS)
- App quit (macOS)
- System-controlled timing (batched, may delay)
- **Not** immediately on save

### When Imports Happen
- App launch
- Remote notification from CloudKit
- System-controlled timing

### Normal Log Patterns
```
Setup event - failed     ← Retry attempt
Setup event - succeeded  ← Success
Import event - failed    ← Normal during setup
Import event - succeeded ← Data imported
Export event - failed    ← Retry attempt
Export event - succeeded ← Data exported
```
Failed events followed by success = **normal CloudKit behavior**

## Debugging CloudKit

### Enable Detailed Logging
Monitor `NSPersistentCloudKitContainer.eventChangedNotification`:
```swift
@Observable class CloudKitSyncMonitor {
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }
}
```

### Check Event Properties
- `event.type`: `.setup`, `.import`, `.export`
- `event.succeeded`: `true`/`false`
- `event.error`: May be `nil` even on failure (normal)

### Common Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Setup fails silently on macOS | Missing network entitlement | Add `com.apple.security.network.client` |
| Setup fails on both platforms | Missing CloudKit configuration | Add `cloudKitDatabase: .private()` |
| Migration error with `sourceImage` | External storage schema mismatch | Delete CloudKit data + local databases |
| No export after save | System batching exports | Background app to trigger |
| Not logged into iCloud | Device/simulator not signed in | Settings → iCloud → Sign in |
| iCloud disabled for app | App permission off | Settings → iCloud → Apps Using iCloud → Enable your app |
| "Entitlements modified during build" | Stale signing cache | Uncheck/recheck "Automatically manage signing" |

## Schema Changes

### Breaking Changes (requires data deletion)
- Adding/removing `@Attribute(.externalStorage)`
- Changing relationship optionality
- Renaming entities/properties

### Safe Changes (auto-migrated)
- Adding new optional properties
- Adding new entities
- Changing default values

### Migration Process
1. Delete data in CloudKit Console (Development environment)
2. Delete local databases:
   - iOS: Delete app
   - macOS: `rm -rf ~/Library/Group\ Containers/group.com.grtnr.Summa/Summa.sqlite*`
3. Rebuild and launch
4. Fresh schema syncs to CloudKit

## CloudKit Console

Access at [icloud.developer.apple.com](https://icloud.developer.apple.com)

### Viewing Data
1. Select your container (e.g., `iCloud.com.grtnr.Summa`)
2. Choose **Development** environment (not Production)
3. Select **Private** database
4. Select zone: `com.apple.coredata.cloudkit.zone` (not `_defaultZone`)
5. Choose record type (e.g., `CD_ValueSnapshot`)
6. Click "Query Records"

### Making Fields Queryable
If query fails with "field not queryable":
1. Go to Schema → Indexes
2. Click + to add new index
3. Select field (e.g., `recordName`)
4. Set as Queryable
5. Return to Data → Records and re-query

### Real-Time Sync Testing
- **Simulators don't receive CloudKit notifications**
- Test: Modify data on simulator → observe changes on physical device
- Or use two physical devices signed into same Apple ID

## Testing Sync

### Quick Verification

1. Add entry on iOS, background app
2. Check logs: `DEBUG Export succeeded`
3. Launch macOS
4. Check logs: `DEBUG Import succeeded`
5. Verify data appears

### Troubleshooting

- **No export logs**: Wait or background app again
- **Import fails on macOS**: Check network entitlement
- **Schema errors**: Delete all data and start fresh
- **CloudKit Console empty**: Wait 30-60 seconds, refresh
- **Not syncing at all**: Verify device signed into iCloud
- **App not in iCloud settings**: Settings → Apple ID → iCloud → Apps Using iCloud

## Key Takeaways

1. **Explicit is better**: Always specify `cloudKitDatabase` parameter
2. **macOS needs network**: Sandbox requires explicit network entitlement
3. **Migrations are hard**: Avoid schema changes that require migration
4. **Failed events are normal**: CloudKit retries internally
5. **System controls timing**: Can't force immediate export
6. **Test cross-platform**: iOS and macOS have different behaviors

## References

### Apple Documentation
- [TN3164: Debugging NSPersistentCloudKitContainer](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)
- [SwiftData CloudKit Sync](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Enabling CloudKit in Your App](https://developer.apple.com/documentation/cloudkit/enabling_cloudkit_in_your_app)
- [Managing iCloud Containers with CloudKit Database App](https://developer.apple.com/documentation/cloudkit/managing_icloud_containers_with_cloudkit_database_app)

### Community
- [grtnr.com: SwiftData on iCloud](https://grtnr.com) - Minimal setup guide
- [100 Days of SwiftUI](https://www.hackingwithswift.com/100/swiftui) - Paul Hudson's excellent course (Day 53-55: SwiftData intro)
