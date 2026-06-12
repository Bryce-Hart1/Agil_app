// Claude  Date 06/08/2026
// Typed configuration loaded from environment variables (.env supported).

pub struct Config {
    pub database_url: String,
    pub bind_addr: String,
}

impl Config {
    // Claude  Date 06/08/2026
    // Read config from the environment, falling back to local-dev defaults.
    pub fn from_env() -> Self {
        Self {
            database_url: std::env::var("DATABASE_URL").unwrap_or_else(|_| "gym.db".to_string()),
            bind_addr: std::env::var("BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".to_string()),
        }
    }
}
