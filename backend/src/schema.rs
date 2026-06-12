// @generated automatically by Diesel CLI.

diesel::table! {
    app_meta (key) {
        key -> Text,
        value -> Text,
    }
}

diesel::table! {
    exercise_sets (id) {
        id -> Text,
        logged_exercise_id -> Text,
        reps -> Integer,
        weight -> Double,
        position -> Integer,
    }
}

diesel::table! {
    exercises (id) {
        id -> Text,
        user_id -> Text,
        name -> Text,
        category -> Text,
        is_unilateral -> Bool,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    logged_exercises (id) {
        id -> Text,
        workout_id -> Text,
        exercise_id -> Text,
        target_rep_min -> Nullable<Integer>,
        target_rep_max -> Nullable<Integer>,
        note -> Nullable<Text>,
        position -> Integer,
    }
}

diesel::table! {
    preset_items (id) {
        id -> Text,
        preset_id -> Text,
        exercise_id -> Text,
        target_rep_min -> Nullable<Integer>,
        target_rep_max -> Nullable<Integer>,
        note -> Nullable<Text>,
        position -> Integer,
    }
}

diesel::table! {
    presets (id) {
        id -> Text,
        user_id -> Text,
        name -> Text,
        symbol_name -> Text,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    users (id) {
        id -> Text,
        display_name -> Text,
        email -> Nullable<Text>,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::table! {
    workouts (id) {
        id -> Text,
        user_id -> Text,
        date -> Text,
        notes -> Text,
        created_at -> Text,
        updated_at -> Text,
    }
}

diesel::joinable!(exercise_sets -> logged_exercises (logged_exercise_id));
diesel::joinable!(exercises -> users (user_id));
diesel::joinable!(logged_exercises -> exercises (exercise_id));
diesel::joinable!(logged_exercises -> workouts (workout_id));
diesel::joinable!(preset_items -> exercises (exercise_id));
diesel::joinable!(preset_items -> presets (preset_id));
diesel::joinable!(presets -> users (user_id));
diesel::joinable!(workouts -> users (user_id));

diesel::allow_tables_to_appear_in_same_query!(
    app_meta,
    exercise_sets,
    exercises,
    logged_exercises,
    preset_items,
    presets,
    users,
    workouts,
);
