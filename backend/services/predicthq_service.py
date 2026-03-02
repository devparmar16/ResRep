"""
PredictHQ conference service — fetches academic conferences with
offset-based pagination, venue/city extraction, and exponential backoff.
"""
import asyncio
import logging
from datetime import date
from typing import Optional, List

import httpx

from config import PREDICTHQ_API_KEY, CONFERENCES_PAGE_SIZE
from models import Conference

logger = logging.getLogger("predicthq_service")


class PredictHQService:
    BASE_URL = "https://api.predicthq.com/v1/events/"
    MAX_RETRIES = 3

    @classmethod
    async def fetch_conferences(
        cls,
        mode: Optional[str] = None,
        country: Optional[str] = None,
        city: Optional[str] = None,
        domain: Optional[str] = None,
        limit: int = CONFERENCES_PAGE_SIZE,
        offset: int = 0,
    ) -> List[Conference]:
        """Fetch conferences from PredictHQ with retry + backoff."""
        headers = {
            "Authorization": f"Bearer {PREDICTHQ_API_KEY}",
            "Accept": "application/json",
        }

        # ── Build query params ───────────────────────────────────
        today = date.today().isoformat()
        params: dict = {
            "category": "conferences",
            "active.gte": today,
            "limit": limit,
            "offset": offset,
            "sort": "start",
            "state": "active",
        }

        # Country filter (ISO-3166-1 alpha-2)
        if country and len(country) == 2:
            params["country"] = country.upper()
        elif country:
            params["q"] = (params.get("q", "") + " " + country).strip()

        # City filter via location text search
        if city:
            params["q"] = (params.get("q", "") + " " + city).strip()

        # Domain / keyword filter
        if domain:
            params["q"] = (params.get("q", "") + " " + domain).strip()

        # Mode filter via text search
        if mode:
            params["q"] = (params.get("q", "") + " " + mode).strip()

        # ── Fetch with exponential backoff ────────────────────────
        async with httpx.AsyncClient(timeout=15.0) as client:
            for attempt in range(cls.MAX_RETRIES):
                try:
                    response = await client.get(
                        cls.BASE_URL, headers=headers, params=params
                    )

                    # Rate limited — back off
                    if response.status_code == 429:
                        wait = 2 ** attempt
                        logger.warning(
                            f"PredictHQ 429 rate-limited. Retry {attempt+1}/{cls.MAX_RETRIES} in {wait}s"
                        )
                        await asyncio.sleep(wait)
                        continue

                    response.raise_for_status()
                    data = response.json()
                    events = data.get("results", [])

                    return cls._normalize_events(events, domain)

                except httpx.HTTPStatusError as e:
                    logger.error(f"PredictHQ HTTP {e.response.status_code}: {e}")
                    if attempt < cls.MAX_RETRIES - 1:
                        await asyncio.sleep(2 ** attempt)
                        continue
                    return []
                except Exception as e:
                    logger.error(f"PredictHQ error: {e}")
                    if attempt < cls.MAX_RETRIES - 1:
                        await asyncio.sleep(2 ** attempt)
                        continue
                    return []

        return []

    @classmethod
    def _normalize_events(cls, events: list, domain: Optional[str]) -> List[Conference]:
        """Extract and normalize PredictHQ event fields into Conference models."""
        conferences = []
        for ev in events:
            title = ev.get("title", "Unknown")

            # ── Location / Geo ──
            loc = ev.get("location")  # [lon, lat]
            lon, lat = (loc[0], loc[1]) if loc and len(loc) == 2 else (None, None)

            country_code = ev.get("country", "")

            # ── Venue / City from entities ──
            venue_name = None
            city = None
            entities = ev.get("entities", [])
            for entity in entities:
                etype = entity.get("type", "")
                if etype == "venue" and not venue_name:
                    venue_name = entity.get("name")
                elif etype == "locality" and not city:
                    city = entity.get("name")

            # Fallback: try geo.address for city
            geo = ev.get("geo", {})
            if not city and geo:
                address = geo.get("address", {})
                if isinstance(address, dict):
                    city = address.get("locality") or address.get("city")

            # ── Description ──
            description = ev.get("description", "")

            # ── Labels / Tags ──
            raw_labels = ev.get("labels", []) or []
            phq_labels = ev.get("phq_labels", []) or []
            all_labels = []
            for lbl in raw_labels + phq_labels:
                if isinstance(lbl, str):
                    all_labels.append(lbl)
                elif isinstance(lbl, dict):
                    name = lbl.get("label") or lbl.get("name") or ""
                    if name:
                        all_labels.append(name)
            all_labels = list(dict.fromkeys(all_labels))  # dedupe preserving order

            # ── Mode detection ──
            ev_mode = "offline"
            lower_title = title.lower()
            if "online" in lower_title or "virtual" in lower_title or "webinar" in lower_title:
                ev_mode = "online"
            elif "hybrid" in lower_title:
                ev_mode = "hybrid"
            elif not loc:
                ev_mode = "online"  # no location likely means virtual

            conferences.append(Conference(
                id=ev.get("id", ""),
                title=title,
                description=description if description else None,
                start_date=ev.get("start"),
                end_date=ev.get("end"),
                venue_name=venue_name,
                city=city,
                country=country_code,
                latitude=lat,
                longitude=lon,
                mode=ev_mode,
                url=ev.get("url") if ev.get("url") else None,
                labels=all_labels,
                domain=domain,
            ))

        return conferences
