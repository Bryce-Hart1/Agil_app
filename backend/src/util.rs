// Claude  Date 06/10/2026
// Small shared helpers.

// The single local user until real accounts arrive (B2). Matches the row seeded
// by the create_core_schema migration.
pub const DEFAULT_USER_ID: &str = "00000000-0000-0000-0000-0000000000aa";

// Claude  Date 06/10/2026
// Current UTC time as an ISO-8601 string with a trailing Z (matches the app's
// JSON date format), e.g. "2026-06-10T03:36:30Z".
pub fn now_iso() -> String {
    chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
}
