"""Kafka helpers shared across all HELEP services.

Pub/Sub  : topics + consumer groups, manual offset commit (at-least-once)
Outbox   : db write and publish live in the same async block in main.py
Circuit  : CircuitBreaker guards every send so a dead broker can't freeze the API
"""
from __future__ import annotations
import json
import os
import time
from typing import Awaitable, Callable, Iterable

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "localhost:9092")

_producer: AIOKafkaProducer | None = None


async def producer() -> AIOKafkaProducer:
    global _producer
    if _producer is None:
        _producer = AIOKafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            enable_idempotence=True,
            acks="all",
            value_serializer=lambda v: json.dumps(v).encode(),
            key_serializer=lambda k: k.encode() if k else None,
        )
        await _producer.start()
    return _producer


async def stop_producer() -> None:
    global _producer
    if _producer is not None:
        await _producer.stop()
        _producer = None


async def health() -> bool:
    """Try to reach the broker. Used by /readyz."""
    try:
        p = await producer()
        await p.client.fetch_all_metadata()
        return True
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Circuit Breaker
# Three states: CLOSED (normal) -> OPEN (broker down, fast-fail all sends)
#               -> HALF_OPEN (cooling done, try one probe) -> CLOSED or OPEN
# ---------------------------------------------------------------------------

class CircuitBreaker:
    """Stops the service from hammering a broken Kafka broker.

    When too many publishes fail in a row we flip OPEN and immediately
    raise on any further publish() call. After reset_after_s seconds we
    allow a single probe; success closes it again, failure restarts the timer.
    """

    CLOSED    = "CLOSED"
    OPEN      = "OPEN"
    HALF_OPEN = "HALF_OPEN"

    def __init__(self, fail_max: int = 5, reset_after_s: float = 10.0) -> None:
        self._state      = self.CLOSED
        self._failures   = 0
        self._opened_at: float | None = None
        self._fail_max   = fail_max
        self._reset_s    = reset_after_s

    # -- read-only state so tests can inspect it
    @property
    def state(self) -> str:
        return self._state

    def _try_reset(self) -> None:
        """Move OPEN -> HALF_OPEN once the cooling window has elapsed."""
        if self._opened_at is not None:
            if (time.monotonic() - self._opened_at) >= self._reset_s:
                self._state = self.HALF_OPEN

    def allow_request(self) -> bool:
        """Return True when the caller should go ahead with the operation."""
        if self._state == self.CLOSED:
            return True
        if self._state == self.OPEN:
            self._try_reset()
            # still open after reset attempt means cooling not done yet
            return self._state == self.HALF_OPEN
        # HALF_OPEN: one probe is allowed through
        return True

    def on_success(self) -> None:
        self._failures  = 0
        self._state     = self.CLOSED
        self._opened_at = None

    def on_failure(self) -> None:
        self._failures += 1
        if self._state == self.HALF_OPEN:
            # probe failed -> stay broken, restart timer
            self._state     = self.OPEN
            self._opened_at = time.monotonic()
        elif self._failures >= self._fail_max:
            self._state     = self.OPEN
            self._opened_at = time.monotonic()


_breaker = CircuitBreaker()


async def publish(topic: str, payload: dict, key: str | None = None) -> None:
    """Send one message. Raises if circuit is open or broker rejects."""
    if not _breaker.allow_request():
        raise RuntimeError(
            f"kafka circuit is OPEN — skipping publish to '{topic}'"
        )
    try:
        p = await producer()
        await p.send_and_wait(topic, value=payload, key=key)
        _breaker.on_success()
    except Exception:
        _breaker.on_failure()
        raise


Handler = Callable[[dict], Awaitable[None]]


async def consume(
    topics: Iterable[str],
    group_id: str,
    handler: Handler,
) -> None:
    """Read forever. Offset only advances after handler returns without error."""
    consumer = AIOKafkaConsumer(
        *topics,
        bootstrap_servers=KAFKA_BOOTSTRAP,
        group_id=group_id,
        enable_auto_commit=False,
        auto_offset_reset="earliest",
        value_deserializer=lambda raw: json.loads(raw.decode()),
    )
    await consumer.start()
    try:
        async for msg in consumer:
            data = msg.value
            data["_stream"] = msg.topic
            try:
                await handler(data)
                await consumer.commit()
            except Exception:
                # leave offset uncommitted -> message re-delivered on restart
                pass
    finally:
        await consumer.stop()
