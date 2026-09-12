from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    DATABASE_URL: str = "postgresql+psycopg://postgres:postgres@localhost:5432/spgasbill"

    SECRET_KEY: str = "change-this-secret"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080

    APP_NAME: str = "SPBilling API"
    DEBUG: bool = True
    API_PREFIX: str = "/api"

    BILL_CODE_DEFAULT: str = "BILL"

    CORS_ORIGINS: str = "*"

    @property
    def database_url_normalized(self) -> str:
        """Hosted providers (Render, Heroku-style) hand out a plain
        "postgres://" or "postgresql://" URL — normalize to the psycopg3
        driver we depend on so a copy-pasted connection string works
        without hand-editing it first."""
        url = self.DATABASE_URL
        if url.startswith("postgres://"):
            return "postgresql+psycopg://" + url[len("postgres://"):]
        if url.startswith("postgresql://"):
            return "postgresql+psycopg://" + url[len("postgresql://"):]
        return url


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
