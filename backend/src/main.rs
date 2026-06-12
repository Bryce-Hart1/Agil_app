// Claude  Date 06/08/2026
// Backend entrypoint: load env/config, build the SQLite pool, run embedded
// migrations, then serve the Axum app. Runs in the terminal via `cargo run`.

mod config;
mod db;
mod error;
mod models;
mod routes;
mod schema;
mod util;

use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load .env (no-op if absent), then set up logging from RUST_LOG.
    dotenvy::dotenv().ok();
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = config::Config::from_env();
    let pool = db::build_pool(&config.database_url)?;
    db::run_migrations(&pool).await?;

    let app = routes::app(pool);
    let addr: SocketAddr = config.bind_addr.parse()?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    tracing::info!("backend listening on http://{addr}");
    axum::serve(listener, app).await?;
    Ok(())
}
