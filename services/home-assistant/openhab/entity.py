"""What the entities of every item type share."""

from __future__ import annotations

from collections.abc import Callable

from homeassistant.core import callback
from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.entity import Entity
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN, NO_VALUE, Item
from .coordinator import OpenHABConfigEntry, OpenHABCoordinator


class OpenHABEntity(CoordinatorEntity[OpenHABCoordinator]):
    """One openHAB item, named after its label, under a single "openHAB" device."""

    _attr_has_entity_name = True

    def __init__(self, coordinator: OpenHABCoordinator, item: Item) -> None:
        super().__init__(coordinator)
        self.item_name: str = item["name"]
        entry = coordinator.config_entry
        self._attr_unique_id = f"{entry.unique_id}_{self.item_name}"
        self._attr_name = item.get("label") or self.item_name
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, entry.entry_id)},
            name="openHAB",
            manufacturer="openHAB",
            configuration_url=coordinator.url,
        )
        self._attr_extra_state_attributes = {"item": self.item_name, "type": item.get("type")}

    @property
    def item(self) -> Item | None:
        return self.coordinator.data.get(self.item_name)

    @property
    def available(self) -> bool:
        # An item deleted in openHAB stays here, unavailable, until it's removed in HA
        return super().available and self.item is not None

    @property
    def raw_state(self) -> str | None:
        """The item's state as openHAB sends it, or None when it has no value."""
        item = self.item
        if item is None or item.get("state") in NO_VALUE:
            return None
        return str(item.get("state"))


def add_items(
    entry: OpenHABConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
    create: Callable[[OpenHABCoordinator, Item], Entity | None],
) -> None:
    """Add an entity for each item that create() handles: now, and whenever openHAB has new ones."""
    coordinator = entry.runtime_data
    seen: set[str] = set()

    @callback
    def add_new() -> None:
        entities = []
        for name, item in coordinator.data.items():
            if name in seen:
                continue
            seen.add(name)
            if (entity := create(coordinator, item)) is not None:
                entities.append(entity)
        if entities:
            async_add_entities(entities)

    add_new()
    entry.async_on_unload(coordinator.async_add_listener(add_new))
