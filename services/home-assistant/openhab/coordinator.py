"""Reads every openHAB item in one request."""

from __future__ import annotations

import logging

import aiohttp

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import CONF_URL
from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .const import DOMAIN, ITEM_FIELDS, SCAN_INTERVAL, Item

_LOGGER = logging.getLogger(__name__)

type OpenHABConfigEntry = ConfigEntry[OpenHABCoordinator]


async def fetch_items(session: aiohttp.ClientSession, url: str) -> dict[str, Item]:
    """Every item, by name."""
    async with session.get(
        f"{url}/rest/items",
        params={"fields": ITEM_FIELDS},
        timeout=aiohttp.ClientTimeout(total=20),
    ) as response:
        response.raise_for_status()
        items = await response.json(content_type=None)
    if not isinstance(items, list):
        raise ValueError("the answer is not a list of items")
    return {item["name"]: item for item in items if isinstance(item, dict) and "name" in item}


class OpenHABCoordinator(DataUpdateCoordinator[dict[str, Item]]):
    """Polls /rest/items; the entities read from its data."""

    def __init__(self, hass: HomeAssistant, entry: OpenHABConfigEntry) -> None:
        super().__init__(
            hass,
            _LOGGER,
            config_entry=entry,
            name=DOMAIN,
            update_interval=SCAN_INTERVAL,
        )
        self.url: str = entry.data[CONF_URL]
        self._session = async_get_clientsession(hass)

    async def _async_update_data(self) -> dict[str, Item]:
        try:
            return await fetch_items(self._session, self.url)
        except (aiohttp.ClientError, TimeoutError, ValueError) as err:
            raise UpdateFailed(f"Could not read the items from {self.url}: {err}") from err
