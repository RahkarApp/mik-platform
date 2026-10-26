# Named MiKYar permissions

`permission_names.dart` defines the 130 nonempty permissions from the MiKYar
spreadsheet and existing product property/price permissions. Reserved positions
remain reserved. Each definition includes its stable string name, Persian label,
group, previous bit index, and optional editor prerequisite.

- `PermissionAccess.hasPermission(PermissionsName.productsEdit)` checks a grant.
- `PermissionAccess.canAccessRecord(own: ..., all: ..., inserter: ...)` checks
  both the current account and a record's creator.
- `PermissionAccess.load(stored, personnelId: id)` replaces the previous account's
  grants. Missing, empty, or malformed legacy values deny access.
- `PermissionAccess.useOwner()` is called only by the MiK owner host. Staff ID 0
  does not grant owner access by itself.
- `MiKYarPermissionDB` is the existing role model; its `permissionNames` property
  exposes a list of string keys. `MiKYarDB.permissionUID` still assigns that role
  to a staff member; existing direct custom grants remain supported.

MiKYar startup loads the server-resolved grants on its active profile. Socket
permission events replace those grants, including an empty revocation. Switching
accounts, deleting a session, or disabling an account clears the active grants.
Branch and warehouse restrictions remain separate from these operation grants.

The MiK role editor operates on named sets. Selecting a dependent grant includes
its prerequisite; deselecting a prerequisite removes its selected dependents.
Loading an existing role never silently adds prerequisites or expands its rights.

## Existing server and Hive compatibility

No Hive type IDs or field IDs were changed. The current server expects a bit
string in `permission`; role saves continue to send it. `encodeLegacy` preserves
reserved and future positions from an existing value. Bit zero is a protocol
marker, excluded from access checks and permission counts.

`decode` also accepts JSON lists of named strings, so a future server can return
named grants. Runtime UI checks no longer index raw permission arrays. Existing
arrays are synchronized only for compatibility, not used for authorization.

These checks control the client UI and record visibility. This repository does
not include the server authorization implementation; its API contract was not
changed by this migration.

## Verification

36 distinct tests passed across the permission catalogue, reactive access state,
MiKYar profile/socket integration, MiK role editor, dashboard, shared frame, and
routing. Analysis of both apps and shared packages reports zero errors; existing
lint warnings remain. `flutter build bundle --debug --no-pub` succeeds for MiKYar.
The APK build was attempted but Gradle failed to download
`kotlin-gradle-plugin-2.1.0-gradle85.jar` with TLS `bad_record_mac / Tag mismatch`.
No application accounts or production data were modified during this migration.
