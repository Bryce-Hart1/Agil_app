// Claude  Date 06/08/2026
// SQLite connection pool (deadpool wrapping the sync Diesel connection) and a
// startup migration runner. Everything that touches the DB goes through this.

use anyhow::Context;
use deadpool_diesel::sqlite::{Manager, Pool, Runtime};
use diesel::prelude::*;
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};

// Claude  Date 06/08/2026
// Embed the migrations/ directory into the binary so the server self-migrates
// on startup — no external diesel CLI needed to run it locally or on a server.
pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

pub type DbPool = Pool;

// Claude  Date 06/08/2026
// Build a connection pool for the given SQLite database url/path.
pub fn build_pool(database_url: &str) -> anyhow::Result<DbPool> {
    let manager = Manager::new(database_url, Runtime::Tokio1);
    let pool = Pool::builder(manager)
        .max_size(8)
        .build()
        .context("failed to build SQLite pool")?;
    Ok(pool)
}

// Claude  Date 06/08/2026
// Enable WAL mode (persists in the db file) and apply any pending migrations.
pub async fn run_migrations(pool: &DbPool) -> anyhow::Result<()> {
    let conn = pool.get().await.context("getting pooled connection")?;
    conn.interact(|conn| {
        diesel::sql_query("PRAGMA journal_mode=WAL;").execute(conn)?;
        conn.run_pending_migrations(MIGRATIONS)
            .map(|_| ())
            .map_err(|e| anyhow::anyhow!("migration error: {e}"))?;
        Ok::<(), anyhow::Error>(())
    })
    .await
    .map_err(|e| anyhow::anyhow!("interact error: {e}"))??;
    Ok(())
}
