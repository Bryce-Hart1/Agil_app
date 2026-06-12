// Claude  Date 06/08/2026
// GET /health — liveness + DB connectivity check. Reads schema_version from
// app_meta to prove the pool, migrations, and SQLite are all working together.

use axum::extract::State;
use axum::Json;
use diesel::prelude::*;
use serde_json::{json, Value};

use crate::db::DbPool;
use crate::error::AppError;
use crate::schema::app_meta;

pub async fn health(State(pool): State<DbPool>) -> Result<Json<Value>, AppError> {
    let conn = pool
        .get()
        .await
        .map_err(|e| AppError::Internal(format!("pool: {e}")))?;

    let version: String = conn
        .interact(|conn| {
            app_meta::table
                .select(app_meta::value)
                .filter(app_meta::key.eq("schema_version"))
                .first::<String>(conn)
        })
        .await
        .map_err(|e| AppError::Internal(format!("interact: {e}")))?
        .map_err(|e| AppError::Internal(format!("db: {e}")))?;

    Ok(Json(json!({ "status": "ok", "db": "ok", "schema_version": version })))
}
