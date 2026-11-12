"""Switch and Contact items as on/off sensors (read-only: they can't switch anything)."""

from __future__ import annotations

from homeassistant.components.binary_sensor import (
    BinarySensorDeviceClass,
    BinarySensorEntity,
)
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .const import Item, item_type
from .coordinator import OpenHABConfigEntry, OpenHABCoordinator
from .entity import OpenHABEntity, add_items


def create(coordinator: OpenHABCoordinator, item: Item) -> BinarySensorEntity | None:
    match item_type(item):
        case "Switch":
            return OnOffSensor(coordinator, item, "ON")
        case "Contact":
            return OnOffSensor(coordinator, item, "OPEN", BinarySensorDeviceClass.OPENING)
    return None


async def async_setup_entry(
    hass: HomeAssistant,
    entry: OpenHABConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    add_items(entry, async_add_entities, create)


class OnOffSensor(OpenHABEntity, BinarySensorEntity):
    def __init__(
        self,
        coordinator: OpenHABCoordinator,
        item: Item,
        on: str,
        device_class: BinarySensorDeviceClass | None = None,
    ) -> None:
        super().__init__(coordinator, item)
        self._on = on
        self._attr_device_class = device_class

    @property
    def is_on(self) -> bool | None:
        raw = self.raw_state
        return None if raw is None else raw == self._on
