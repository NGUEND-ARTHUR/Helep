"""Pattern: Strategy. Plug-in matching algorithms for choosing a responder.

Switch via env MATCHER=nearest|credibility|roundrobin.
"""
from __future__ import annotations
import math
import os
from typing import Iterable, Protocol


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


class Responder(Protocol):
    id: str
    lat: float
    lon: float
    credibility: float


class Matcher(Protocol):
    def pick(self, victim_lat: float, victim_lon: float, responders: Iterable) -> dict | None: ...


class NearestMatcher:
    def pick(self, victim_lat, victim_lon, responders):
        best = None
        best_d = float("inf")
        for r in responders:
            d = haversine_m(victim_lat, victim_lon, r["lat"], r["lon"])
            if d < best_d:
                best, best_d = r, d
        return {"id": best["id"], "distance_m": best_d} if best else None


class CredibilityWeightedMatcher:
    """Score = credibility / (distance_km + 1). Higher score wins."""
    def pick(self, victim_lat, victim_lon, responders):
        best = None
        best_score = -1.0
        for r in responders:
            d_km = haversine_m(victim_lat, victim_lon, r["lat"], r["lon"]) / 1000.0
            score = r["credibility"] / (d_km + 1.0)
            if score > best_score:
                best, best_score = r, score
        if not best:
            return None
        return {"id": best["id"], "score": best_score}


class RoundRobinMatcher:
    """Rotate through all free units regardless of distance.

    Useful when responders are evenly spread and we want fair workload
    distribution instead of always picking whoever is closest to the hotspot.
    A class-level counter persists for the lifetime of the process.
    """

    _turn: int = 0   # shared across all calls within one pod

    def pick(self, victim_lat: float, victim_lon: float, responders) -> dict | None:
        pool = list(responders)
        if not pool:
            return None
        chosen = pool[RoundRobinMatcher._turn % len(pool)]
        RoundRobinMatcher._turn += 1
        dist = haversine_m(victim_lat, victim_lon, chosen["lat"], chosen["lon"])
        return {"id": chosen["id"], "distance_m": round(dist, 2)}


def matcher() -> Matcher:
    """Factory — reads MATCHER env-var each call so it can be changed at runtime."""
    choice = os.getenv("MATCHER", "nearest").lower()
    if choice == "credibility":
        return CredibilityWeightedMatcher()
    if choice == "roundrobin":
        return RoundRobinMatcher()
    return NearestMatcher()
