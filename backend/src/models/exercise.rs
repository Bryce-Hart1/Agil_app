// Claude  Date 06/10/2026
// Models for the exercises table: the stored row, the insert row, partial-update
// changes, and the request DTOs the API accepts.

use diesel::prelude::*;
use serde::{Deserialize, Serialize};

use crate::schema::exercises;

// Claude  Date 06/10/2026
// A stored exercise, serialized to JSON in camelCase to line up with the app.
#[derive(Debug, Clone, Queryable, Selectable, Serialize)]
#[diesel(table_name = exercises)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
#[serde(rename_all = "camelCase")]
pub struct Exercise {
    pub id: String,
    pub user_id: String,
    pub name: String,
    pub category: String,
    pub is_unilateral: bool,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = exercises)]
pub struct NewExerciseRow {
    pub id: String,
    pub user_id: String,
    pub name: String,
    pub category: String,
    pub is_unilateral: bool,
    pub created_at: String,
    pub updated_at: String,
}

// Claude  Date 06/10/2026
// Partial update; None fields are left unchanged (Diesel skips them).
#[derive(Debug, AsChangeset)]
#[diesel(table_name = exercises)]
pub struct ExerciseChanges {
    pub name: Option<String>,
    pub category: Option<String>,
    pub is_unilateral: Option<bool>,
    pub updated_at: String,
}

// Claude  Date 06/10/2026
// POST body. `id` is optional so the client can supply its own UUID, keeping
// client and server identities aligned for sync.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateExercise {
    pub id: Option<String>,
    pub name: String,
    pub category: Option<String>,
    pub is_unilateral: Option<bool>,
}

// PUT body — all fields optional (partial update).
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateExercise {
    pub name: Option<String>,
    pub category: Option<String>,
    pub is_unilateral: Option<bool>,
}
