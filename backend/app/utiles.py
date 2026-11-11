from datetime import datetime, timezone


def ahora() -> datetime:
    return datetime.now(timezone.utc)
