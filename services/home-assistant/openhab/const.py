"""Constants for the read-only openHAB integration."""

from datetime import timedelta
from typing import Any

DOMAIN = "openhab"
SCAN_INTERVAL = timedelta(seconds=60)
ITEM_FIELDS = "name,label,type,state,stateDescription"
# What openHAB reports for an item that has no value (yet)
NO_VALUE = {"NULL", "UNDEF"}

type Item = dict[str, Any]


def item_type(item: Item) -> str:
    """The base type: "Number:Temperature" is a Number."""
    return str(item.get("type", "")).split(":", 1)[0]
