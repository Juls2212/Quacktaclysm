"""A small in-memory per-IP rate limiter (sliding window). Not a substitute for authentication: see README ("Servicio de IA")."""
from __future__ import annotations

import time
from collections import defaultdict, deque
from typing import Callable

WINDOW_SECONDS = 60.0


class RateLimiter:
    def __init__(self, per_minute: int, clock: Callable[[], float] = time.monotonic) -> None:
        self.per_minute = per_minute
        self._clock = clock
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def allow(self, key: str) -> bool:
        """True and records the hit when `key` is under the limit; a limit of 0 or less disables the check."""
        if self.per_minute <= 0:
            return True
        now = self._clock()
        hits = self._hits[key]
        while hits and now - hits[0] >= WINDOW_SECONDS:
            hits.popleft()
        if len(hits) >= self.per_minute:
            return False
        hits.append(now)
        return True
