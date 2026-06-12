// Claude  Date 06/10/2026
// Application error type that maps failures into JSON HTTP responses, so
// handlers can return `Result<_, AppError>` and use `?`.

use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

#[derive(Debug)]
pub enum AppError {
    Internal(String),
    NotFound(String),
}

impl AppError {
    // Claude  Date 06/10/2026
    // Wrap any displayable error (pool/interact/etc.) as a 500.
    pub fn internal(error: impl std::fmt::Display) -> Self {
        AppError::Internal(error.to_string())
    }
}

// Claude  Date 06/10/2026
// Let handlers use `?` on Diesel query results; a missing row becomes a 404.
impl From<diesel::result::Error> for AppError {
    fn from(error: diesel::result::Error) -> Self {
        match error {
            diesel::result::Error::NotFound => AppError::NotFound("not found".into()),
            other => AppError::Internal(other.to_string()),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::Internal(m) => (StatusCode::INTERNAL_SERVER_ERROR, m),
            AppError::NotFound(m) => (StatusCode::NOT_FOUND, m),
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}
