from __future__ import annotations

import argparse
import html
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import requests
from bs4 import BeautifulSoup

try:
    import cloudscraper
except ImportError:
    cloudscraper = None

SEARCH_URL = (
        "https://www.pccomponentes.pt/search?query=google+pixel+10+pro"
        "&sort=price_asc&families[]=1116&brands[]=904&filter_group_58[]=40614"
)

GOTIFY_URL = os.getenv("GOTIFY_URL", "http://localhost:8082")
GOTIFY_TOKEN = os.getenv("GOTIFY_TOKEN", "")
# systemd sets STATE_DIRECTORY for units with StateDirectory=
STATE_FILE = Path(os.getenv("STATE_DIRECTORY", Path(__file__).parent)) / "pccomponentes_state.json"
DAILY_NOTIFICATION_HOUR = 10

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;q=0.9,"
        "image/avif,image/webp,image/apng,*/*;q=0.8"
    ),
    "Accept-Language": "pt-PT,pt;q=0.9,en-US;q=0.8,en;q=0.7",
    "Cache-Control": "no-cache",
    "Pragma": "no-cache",
    "DNT": "1",
    "Upgrade-Insecure-Requests": "1",
}


def now_ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def log(message: str) -> None:
    print(f"{now_ts()} {message}")


def send_gotify(title: str, message: str, priority: int = 5) -> bool:
    if not GOTIFY_URL or not GOTIFY_TOKEN:
        log("Gotify notification skipped: GOTIFY_URL or GOTIFY_TOKEN not set")
        return False

    url = GOTIFY_URL.rstrip("/") + "/message?token=" + GOTIFY_TOKEN
    payload = json.dumps({"title": title, "message": message, "priority": priority}).encode("utf-8")

    try:
        response = requests.post(
            url,
            data=payload,
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        log(f"Gotify notify error: {exc}")
        return False

    return True


def load_state() -> dict[str, Any]:
    try:
        raw_state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError) as exc:
        log(f"State file could not be read, resetting state: {exc}")
        return {}

    return raw_state if isinstance(raw_state, dict) else {}


def save_state(state: dict[str, Any]) -> None:
    try:
        STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")
    except OSError as exc:
        log(f"State file could not be written: {exc}")


def should_send_daily_notification(state: dict[str, Any], current_time: datetime) -> bool:
    if current_time.hour != DAILY_NOTIFICATION_HOUR:
        return False

    today = current_time.date().isoformat()
    return state.get("last_daily_notification_date") != today


def format_price_message(product: dict[str, Any], url: str) -> str:
    return (
        f"{product['title']}\n"
        f"Price: {product['price']:.2f} EUR\n"
        f"Product ID: {product['id']}\n"
        f"URL: {url}"
    )


def update_price_state(
    state: dict[str, Any],
    product: dict[str, Any],
    url: str,
    current_time: datetime,
) -> bool:
    previous_price = state.get("price")
    if previous_price == product["price"]:
        return False

    state["price"] = product["price"]
    state["title"] = product["title"]
    state["id"] = product["id"]
    state["url"] = url
    state["updated_at"] = current_time.isoformat(timespec="seconds")
    return True


def fetch_search_page(url: str) -> str:
    if cloudscraper is not None:
        scraper = cloudscraper.create_scraper(
            browser={"browser": "chrome", "platform": "windows", "mobile": False}
        )
        scraper.headers.update(HEADERS)
        response = scraper.get(url, timeout=30)
        response.raise_for_status()
        return response.text

    session = requests.Session()
    session.headers.update(HEADERS)

    homepage_response = session.get("https://www.pccomponentes.pt/", timeout=20)
    homepage_response.raise_for_status()

    response = session.get(
        url,
        headers={
            "Referer": "https://www.pccomponentes.pt/",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "same-origin",
            "Sec-Fetch-User": "?1",
        },
        timeout=20,
    )
    response.raise_for_status()
    return response.text


def parse_products(html_text: str) -> list[dict[str, Any]]:
    soup = BeautifulSoup(html_text, "html.parser")
    products: list[dict[str, Any]] = []

    for tag in soup.select("[data-product-id]"):
        price_str = tag.get("data-product-price")
        product_id = tag.get("data-product-id")
        if not price_str or not product_id:
            continue

        try:
            price = float(price_str)
        except ValueError:
            continue

        title = tag.get("title") or tag.get("data-product-name") or ""
        if not title:
            image = tag.find("img")
            if image is not None:
                title = image.get("alt") or image.get("title") or ""

        title = html.unescape(title).strip() or f"Product {product_id}"

        products.append({
            "id": product_id,
            "title": title,
            "price": price,
        })

    return products


def format_cheapest(product: dict[str, Any]) -> str:
    return (
        f"Cheapest listing:\n"
        f"  {product['title']}\n"
        f"  Price: {product['price']:.2f} EUR\n"
        f"  Product ID: {product['id']}\n"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Track the cheapest PCComponentes listing for a single search URL."
    )
    parser.add_argument(
        "--url",
        help="Search URL to fetch. If omitted, the built-in SEARCH_URL is used.",
    )
    args = parser.parse_args(argv)
    url = args.url if args.url else SEARCH_URL

    log(f"Fetching: {url}")
    try:
        html_text = fetch_search_page(url)
    except requests.RequestException as exc:
        print(f"Request failed for {url}: {exc}", file=sys.stderr)
        return 1

    products = parse_products(html_text)
    if not products:
        print(f"No product listings were found for {url}.", file=sys.stderr)
        return 1

    cheapest = min(products, key=lambda item: item["price"])
    current_time = datetime.now()
    state = load_state()
    previous_price = state.get("price")
    state_changed = update_price_state(state, cheapest, url, current_time)

    if isinstance(previous_price, (int, float)):
        log(
            "Current cheapest price: "
            f"{cheapest['price']:.2f} EUR (previous: {float(previous_price):.2f} EUR)"
        )
    else:
        log(f"Current cheapest price: {cheapest['price']:.2f} EUR")

    if isinstance(previous_price, (int, float)) and cheapest["price"] < float(previous_price):
        msg = (
            f"Price dropped from {float(previous_price):.2f} EUR to {cheapest['price']:.2f} EUR\n\n"
            f"{format_price_message(cheapest, url)}"
        )
        sent = send_gotify("PCComponentes price dropped", msg)
        log(f"Gotify notification sent: {sent}")

    if should_send_daily_notification(state, current_time):
        msg = format_price_message(cheapest, url)
        sent = send_gotify("PCComponentes current price", msg)
        log(f"Daily Gotify notification sent: {sent}")
        state["last_daily_notification_date"] = current_time.date().isoformat()
        state_changed = True

    if state_changed:
        save_state(state)

    print(format_cheapest(cheapest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
