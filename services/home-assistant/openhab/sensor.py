"""Number, Dimmer and Rollershutter items as numeric sensors; String and DateTime as text and time."""

from __future__ import annotations

import re
from datetime import datetime

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorStateClass,
)
from homeassistant.const import (
    PERCENTAGE,
    UnitOfElectricCurrent,
    UnitOfElectricPotential,
    UnitOfPower,
    UnitOfTemperature,
)
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.util import dt as dt_util

from .const import Item, item_type
from .coordinator import OpenHABConfigEntry, OpenHABCoordinator
from .entity import OpenHABEntity, add_items

# Units openHAB shows (in a state like "21.5 °C", or a display pattern like "%.1f °C") that HA knows
UNITS: dict[str, tuple[SensorDeviceClass | None, str]] = {
    "°C": (SensorDeviceClass.TEMPERATURE, UnitOfTemperature.CELSIUS),
    "°F": (SensorDeviceClass.TEMPERATURE, UnitOfTemperature.FAHRENHEIT),
    "%": (None, PERCENTAGE),
    "W": (SensorDeviceClass.POWER, UnitOfPower.WATT),
    "kW": (SensorDeviceClass.POWER, UnitOfPower.KILO_WATT),
    "V": (SensorDeviceClass.VOLTAGE, UnitOfElectricPotential.VOLT),
    "A": (SensorDeviceClass.CURRENT, UnitOfElectricCurrent.AMPERE),
}
# "%.1f °C": the decimals, then whatever follows the number
PATTERN = re.compile(r"%[-#+ 0,(]*\d*(?:\.(\d+))?[a-zA-Z]\s*(.*)$")


def number_format(item: Item) -> tuple[str | None, int | None]:
    """The unit and the decimals openHAB displays the item with."""
    pattern = str((item.get("stateDescription") or {}).get("pattern") or "")
    unit, decimals = None, None
    if match := PATTERN.search(pattern):
        decimals = int(match[1]) if match[1] is not None else None
        unit = match[2].replace("%%", "%").strip() or None
    if unit in (None, "%unit%"):
        # Items with a dimension carry the unit in their state: "21.5 °C"
        parts = str(item.get("state", "")).split(" ", 1)
        unit = parts[1].strip() if len(parts) == 2 else None
    return unit, decimals


def create(coordinator: OpenHABCoordinator, item: Item) -> SensorEntity | None:
    match item_type(item):
        case "Number":
            unit, decimals = number_format(item)
            device_class, unit = UNITS.get(unit or "", (None, None))
            return NumberSensor(coordinator, item, device_class, unit, decimals)
        case "Dimmer" | "Rollershutter":
            return NumberSensor(coordinator, item, None, PERCENTAGE, 0)
        case "String":
            return TextSensor(coordinator, item)
        case "DateTime":
            return TimeSensor(coordinator, item)
    return None


async def async_setup_entry(
    hass: HomeAssistant,
    entry: OpenHABConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    add_items(entry, async_add_entities, create)


class NumberSensor(OpenHABEntity, SensorEntity):
    _attr_state_class = SensorStateClass.MEASUREMENT

    def __init__(
        self,
        coordinator: OpenHABCoordinator,
        item: Item,
        device_class: SensorDeviceClass | None,
        unit: str | None,
        decimals: int | None,
    ) -> None:
        super().__init__(coordinator, item)
        self._attr_device_class = device_class
        self._attr_native_unit_of_measurement = unit
        self._attr_suggested_display_precision = decimals

    @property
    def native_value(self) -> float | None:
        if (raw := self.raw_state) is None:
            return None
        try:
            return float(raw.split(" ", 1)[0])
        except ValueError:
            return None


class TextSensor(OpenHABEntity, SensorEntity):
    @property
    def native_value(self) -> str | None:
        raw = self.raw_state
        return None if raw is None else raw[:255]


class TimeSensor(OpenHABEntity, SensorEntity):
    _attr_device_class = SensorDeviceClass.TIMESTAMP

    @property
    def native_value(self) -> datetime | None:
        if (raw := self.raw_state) is None or (value := dt_util.parse_datetime(raw)) is None:
            return None
        if value.tzinfo is None:
            value = value.replace(tzinfo=dt_util.get_default_time_zone())
        return value
