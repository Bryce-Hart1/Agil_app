// Claude  Date 06/10/2026
// CRUD for /exercises, scoped to the single local user (DEFAULT_USER_ID) until
// real accounts arrive in B2.

use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::Json;
use diesel::prelude::*;

use crate::db::DbPool;
use crate::error::AppError;
use crate::models::exercise::{
    CreateExercise, Exercise, ExerciseChanges, NewExerciseRow, UpdateExercise,
};
use crate::schema::exercises;
use crate::util::{now_iso, DEFAULT_USER_ID};

// GET /exercises — list this user's exercises, A→Z.
pub async fn list(State(pool): State<DbPool>) -> Result<Json<Vec<Exercise>>, AppError> {
    let conn = pool.get().await.map_err(AppError::internal)?;
    let rows = conn
        .interact(|c| {
            exercises::table
                .filter(exercises::user_id.eq(DEFAULT_USER_ID))
                .order(exercises::name.asc())
                .select(Exercise::as_select())
                .load::<Exercise>(c)
        })
        .await
        .map_err(AppError::internal)??;
    Ok(Json(rows))
}

// POST /exercises — create one (client may supply its own id).
pub async fn create(
    State(pool): State<DbPool>,
    Json(req): Json<CreateExercise>,
) -> Result<(StatusCode, Json<Exercise>), AppError> {
    let now = now_iso();
    let row = NewExerciseRow {
        id: req.id.unwrap_or_else(|| uuid::Uuid::new_v4().to_string()),
        user_id: DEFAULT_USER_ID.to_string(),
        name: req.name,
        category: req.category.unwrap_or_else(|| "Other".to_string()),
        is_unilateral: req.is_unilateral.unwrap_or(false),
        created_at: now.clone(),
        updated_at: now,
    };
    let conn = pool.get().await.map_err(AppError::internal)?;
    let created = conn
        .interact(move |c| -> QueryResult<Exercise> {
            diesel::insert_into(exercises::table).values(&row).execute(c)?;
            exercises::table
                .filter(exercises::id.eq(&row.id))
                .select(Exercise::as_select())
                .first(c)
        })
        .await
        .map_err(AppError::internal)??;
    Ok((StatusCode::CREATED, Json(created)))
}

// GET /exercises/{id}
pub async fn get_one(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<Json<Exercise>, AppError> {
    let conn = pool.get().await.map_err(AppError::internal)?;
    let found = conn
        .interact(move |c| {
            exercises::table
                .filter(exercises::id.eq(&id))
                .filter(exercises::user_id.eq(DEFAULT_USER_ID))
                .select(Exercise::as_select())
                .first::<Exercise>(c)
                .optional()
        })
        .await
        .map_err(AppError::internal)??;
    found
        .map(Json)
        .ok_or_else(|| AppError::NotFound("exercise not found".into()))
}

// PUT /exercises/{id} — partial update.
pub async fn update(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
    Json(req): Json<UpdateExercise>,
) -> Result<Json<Exercise>, AppError> {
    let changes = ExerciseChanges {
        name: req.name,
        category: req.category,
        is_unilateral: req.is_unilateral,
        updated_at: now_iso(),
    };
    let conn = pool.get().await.map_err(AppError::internal)?;
    let updated = conn
        .interact(move |c| -> QueryResult<Option<Exercise>> {
            let affected = diesel::update(
                exercises::table
                    .filter(exercises::id.eq(&id))
                    .filter(exercises::user_id.eq(DEFAULT_USER_ID)),
            )
            .set(&changes)
            .execute(c)?;
            if affected == 0 {
                return Ok(None);
            }
            exercises::table
                .filter(exercises::id.eq(&id))
                .select(Exercise::as_select())
                .first(c)
                .optional()
        })
        .await
        .map_err(AppError::internal)??;
    updated
        .map(Json)
        .ok_or_else(|| AppError::NotFound("exercise not found".into()))
}

// DELETE /exercises/{id}
pub async fn delete(
    State(pool): State<DbPool>,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    let conn = pool.get().await.map_err(AppError::internal)?;
    let affected = conn
        .interact(move |c| {
            diesel::delete(
                exercises::table
                    .filter(exercises::id.eq(&id))
                    .filter(exercises::user_id.eq(DEFAULT_USER_ID)),
            )
            .execute(c)
        })
        .await
        .map_err(AppError::internal)??;
    if affected == 0 {
        Err(AppError::NotFound("exercise not found".into()))
    } else {
        Ok(StatusCode::NO_CONTENT)
    }
}
