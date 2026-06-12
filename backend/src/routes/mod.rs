// Claude  Date 06/10/2026
// Assembles the Axum router and shares the DB pool as application state.

use axum::{
    routing::get,
    Router,
};

use crate::db::DbPool;

mod exercises;
mod health;

// Claude  Date 06/10/2026
// Build the application router. New route modules get mounted here.
pub fn app(pool: DbPool) -> Router {
    Router::new()
        .route("/health", get(health::health))
        .route("/exercises", get(exercises::list).post(exercises::create))
        .route(
            "/exercises/{id}",
            get(exercises::get_one).put(exercises::update).delete(exercises::delete),
        )
        .with_state(pool)
}
