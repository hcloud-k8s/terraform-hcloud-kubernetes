#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import html
import io
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP


GITHUB_GRAPHQL_URL = "https://api.github.com/graphql"
LIBERAPAY_AVATAR_FALLBACK = "https://liberapay.com/assets/liberapay/icon-v2_black.200.png"
WEEKS_PER_YEAR = Decimal("52")
MONTHS_PER_YEAR = Decimal("12")
REGULAR_WIDTH = "80px"
HIGHLIGHTED_WIDTH = "120px"
SUPPORTED_CURRENCIES = {"USD", "EUR"}
GITHUB_QUERY_TEMPLATE = """
query($login:String!,$first:Int!,$after:String){
  __OWNER_TYPE__(login:$login){
    sponsorshipsAsMaintainer(first:$first, after:$after, activeOnly:true, includePrivate:false){
      pageInfo{hasNextPage endCursor}
      nodes{
        id
        createdAt
        isActive
        isOneTimePayment
        privacyLevel
        sponsorEntity{
          __typename
          ... on User{ login name url }
          ... on Organization{ login name url }
        }
        tier{
          monthlyPriceInCents
          monthlyPriceInDollars
        }
      }
    }
  }
}
""".strip()


@dataclass(frozen=True)
class Sponsor:
    platform: str
    key: str
    name: str
    profile_url: str
    avatar_url: str
    started_at: datetime
    tier: str
    monthly_amount: Decimal
    currency: str


@dataclass(frozen=True)
class Thresholds:
    github_regular_monthly_minimum: Decimal
    github_highlighted_monthly_minimum: Decimal
    liberapay_regular_weekly_minimum: Decimal
    liberapay_highlighted_weekly_minimum: Decimal


def decimal_arg(value: str) -> Decimal:
    parsed = parse_decimal(value)
    if parsed is None:
        raise argparse.ArgumentTypeError(f"Invalid decimal value: {value}")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Merge GitHub Sponsors and Liberapay patrons into README markers.")
    parser.add_argument("--github-login", required=True, help="GitHub organization or user login to query.")
    parser.add_argument("--liberapay-username", help="Liberapay username to query.")
    parser.add_argument(
        "--github-regular-monthly-minimum",
        required=True,
        type=decimal_arg,
        help="Minimum GitHub monthly amount for regular sponsors.",
    )
    parser.add_argument(
        "--github-highlighted-monthly-minimum",
        required=True,
        type=decimal_arg,
        help="Minimum GitHub monthly amount for highlighted sponsors.",
    )
    parser.add_argument(
        "--liberapay-regular-weekly-minimum",
        required=True,
        type=decimal_arg,
        help="Minimum Liberapay weekly amount for regular sponsors.",
    )
    parser.add_argument(
        "--liberapay-highlighted-weekly-minimum",
        required=True,
        type=decimal_arg,
        help="Minimum Liberapay weekly amount for highlighted sponsors.",
    )
    parser.add_argument("--readme", default="README.md", help="README file to update.")
    return parser.parse_args()


def fetch_text(url: str, *, headers: dict[str, str] | None = None, data: bytes | None = None) -> str:
    request = urllib.request.Request(url, headers=headers or {}, data=data)
    with urllib.request.urlopen(request) as response:
        encoding = response.headers.get_content_charset("utf-8")
        return response.read().decode(encoding)


def fetch_json(url: str, *, headers: dict[str, str] | None = None, data: bytes | None = None) -> dict:
    return json.loads(fetch_text(url, headers=headers, data=data))


def parse_decimal(value: object) -> Decimal | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return Decimal(text)
    except InvalidOperation:
        return None


def parse_started_at(value: str, *, date_only: bool = False) -> datetime | None:
    text = value.strip()
    if not text:
        return None
    try:
        if date_only:
            return datetime.fromisoformat(f"{text}T00:00:00+00:00")
        return datetime.fromisoformat(text.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def build_thresholds(args: argparse.Namespace) -> Thresholds:
    thresholds = Thresholds(
        github_regular_monthly_minimum=args.github_regular_monthly_minimum,
        github_highlighted_monthly_minimum=args.github_highlighted_monthly_minimum,
        liberapay_regular_weekly_minimum=args.liberapay_regular_weekly_minimum,
        liberapay_highlighted_weekly_minimum=args.liberapay_highlighted_weekly_minimum,
    )
    for value in (
        thresholds.github_regular_monthly_minimum,
        thresholds.github_highlighted_monthly_minimum,
        thresholds.liberapay_regular_weekly_minimum,
        thresholds.liberapay_highlighted_weekly_minimum,
    ):
        if value < 0:
            raise RuntimeError("Threshold values must be non-negative.")
    if thresholds.github_highlighted_monthly_minimum < thresholds.github_regular_monthly_minimum:
        raise RuntimeError("GitHub highlighted minimum must be greater than or equal to the GitHub regular minimum.")
    if thresholds.liberapay_highlighted_weekly_minimum < thresholds.liberapay_regular_weekly_minimum:
        raise RuntimeError("Liberapay highlighted minimum must be greater than or equal to the Liberapay regular minimum.")
    return thresholds


def monthly_tier(
    monthly_amount: Decimal,
    *,
    regular_minimum: Decimal,
    highlighted_minimum: Decimal,
) -> str | None:
    if monthly_amount >= highlighted_minimum:
        return "highlighted"
    if regular_minimum <= monthly_amount < highlighted_minimum:
        return "regular"
    return None


def liberapay_tier(weekly_amount: Decimal, annual_amount: Decimal, thresholds: Thresholds) -> str | None:
    if weekly_amount >= thresholds.liberapay_highlighted_weekly_minimum:
        return "highlighted"
    if weekly_amount >= thresholds.liberapay_regular_weekly_minimum:
        return "regular"
    return None


def fetch_liberapay_sponsors(username: str, thresholds: Thresholds) -> list[Sponsor]:
    csv_url = f"https://liberapay.com/{urllib.parse.quote(username)}/patrons/public.csv"
    csv_data = fetch_text(csv_url)
    sponsors: list[Sponsor] = []

    for row in csv.DictReader(io.StringIO(csv_data)):
        sponsor_username = (row.get("patron_username") or "").strip()
        if not sponsor_username:
            continue

        currency = (row.get("donation_currency") or "").strip().upper()
        if currency not in SUPPORTED_CURRENCIES:
            continue

        weekly_amount = parse_decimal(row.get("weekly_amount"))
        if weekly_amount is None:
            continue

        started_at = parse_started_at(row.get("pledge_date") or "", date_only=True)
        if started_at is None:
            continue

        annual_amount = weekly_amount * WEEKS_PER_YEAR
        tier = liberapay_tier(weekly_amount, annual_amount, thresholds)
        if tier is None:
            continue
        monthly_amount = (annual_amount / MONTHS_PER_YEAR).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

        display_name = (row.get("patron_public_name") or sponsor_username).strip() or sponsor_username
        avatar_url = (row.get("patron_avatar_url") or "").strip() or LIBERAPAY_AVATAR_FALLBACK

        sponsors.append(
            Sponsor(
                platform="liberapay",
                key=sponsor_username.lower(),
                name=display_name,
                profile_url=f"https://liberapay.com/{urllib.parse.quote(sponsor_username)}",
                avatar_url=avatar_url,
                started_at=started_at,
                tier=tier,
                monthly_amount=monthly_amount,
                currency=currency,
            )
        )

    return sponsors


def fetch_github_sponsors(login: str, token: str, thresholds: Thresholds) -> list[Sponsor]:
    for owner_type in ("organization", "user"):
        sponsors: list[Sponsor] = []
        after: str | None = None

        while True:
            payload = json.dumps(
                {
                    "query": GITHUB_QUERY_TEMPLATE.replace("__OWNER_TYPE__", owner_type),
                    "variables": {
                        "login": login,
                        "first": 100,
                        "after": after,
                    },
                }
            ).encode("utf-8")

            response = fetch_json(
                GITHUB_GRAPHQL_URL,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                data=payload,
            )

            if response.get("errors"):
                error_types = {error.get("type") for error in response["errors"]}
                if error_types == {"NOT_FOUND"}:
                    sponsors = []
                    break
                raise RuntimeError(f"GitHub GraphQL query failed: {response['errors']}")

            container = response.get("data", {}).get(owner_type)
            if not container:
                sponsors = []
                break

            sponsorships = container.get("sponsorshipsAsMaintainer") or {}
            for node in sponsorships.get("nodes", []):
                if not node.get("isActive") or node.get("isOneTimePayment"):
                    continue
                if node.get("privacyLevel") != "PUBLIC":
                    continue

                sponsor_entity = node.get("sponsorEntity") or {}
                sponsor_login = (sponsor_entity.get("login") or "").strip()
                sponsor_url = (sponsor_entity.get("url") or "").strip()
                if not sponsor_login or not sponsor_url:
                    continue

                started_at = parse_started_at(node.get("createdAt") or "")
                if started_at is None:
                    continue

                cents = parse_decimal((node.get("tier") or {}).get("monthlyPriceInCents"))
                if cents is None:
                    dollars = parse_decimal((node.get("tier") or {}).get("monthlyPriceInDollars"))
                    if dollars is None:
                        continue
                    monthly_amount = dollars
                else:
                    monthly_amount = cents / Decimal("100")

                tier = monthly_tier(
                    monthly_amount,
                    regular_minimum=thresholds.github_regular_monthly_minimum,
                    highlighted_minimum=thresholds.github_highlighted_monthly_minimum,
                )
                if tier is None:
                    continue

                display_name = (sponsor_entity.get("name") or sponsor_login).strip() or sponsor_login
                sponsors.append(
                    Sponsor(
                        platform="github",
                        key=sponsor_login.lower(),
                        name=display_name,
                        profile_url=sponsor_url,
                        avatar_url=f"https://github.com/{urllib.parse.quote(sponsor_login)}.png",
                        started_at=started_at,
                        tier=tier,
                        monthly_amount=monthly_amount,
                        currency="USD",
                    )
                )

            page_info = sponsorships.get("pageInfo") or {}
            if not page_info.get("hasNextPage"):
                return sponsors

            after = page_info.get("endCursor")

    raise RuntimeError(f"Unable to find GitHub organization or user '{login}'.")


def sort_and_dedupe(sponsors: list[Sponsor]) -> list[Sponsor]:
    unique: dict[tuple[str, str], Sponsor] = {}
    for sponsor in sponsors:
        unique[(sponsor.platform, sponsor.key)] = sponsor

    return sorted(
        unique.values(),
        key=lambda sponsor: (sponsor.started_at, sponsor.name.casefold(), sponsor.platform, sponsor.key),
    )


def render_sponsor(sponsor: Sponsor, width: str) -> str:
    return (
        f'<a href="{html.escape(sponsor.profile_url, quote=True)}">'
        f'<img src="{html.escape(sponsor.avatar_url, quote=True)}" '
        f'width="{width}" alt="{html.escape(sponsor.name)}" /></a>&nbsp;&nbsp;'
    )


def replace_marker(content: str, marker: str, replacement: str) -> str:
    pattern = re.compile(rf"<!-- {re.escape(marker)} -->.*?<!-- {re.escape(marker)} -->", re.DOTALL)
    updated_content, count = pattern.subn(f"<!-- {marker} -->{replacement}<!-- {marker} -->", content, count=1)
    if count != 1:
        raise RuntimeError(f"README marker '{marker}' was not found exactly once.")
    return updated_content


def main() -> int:
    args = parse_args()
    thresholds = build_thresholds(args)
    github_token = os.environ.get("GITHUB_TOKEN", "").strip()
    if not github_token:
        raise RuntimeError("GITHUB_TOKEN is required to fetch GitHub Sponsors data.")

    sponsors = fetch_github_sponsors(args.github_login, github_token, thresholds)
    if args.liberapay_username:
        sponsors = fetch_liberapay_sponsors(args.liberapay_username, thresholds) + sponsors

    regular_sponsors = sort_and_dedupe(
        [sponsor for sponsor in sponsors if sponsor.tier == "regular"]
    )
    highlighted_sponsors = sort_and_dedupe(
        [sponsor for sponsor in sponsors if sponsor.tier == "highlighted"]
    )

    with open(args.readme, "r", encoding="utf-8") as readme_file:
        readme = readme_file.read()

    readme = replace_marker(
        readme,
        "sponsors-highlighted",
        "".join(render_sponsor(sponsor, HIGHLIGHTED_WIDTH) for sponsor in highlighted_sponsors),
    )
    readme = replace_marker(
        readme,
        "sponsors",
        "".join(render_sponsor(sponsor, REGULAR_WIDTH) for sponsor in regular_sponsors),
    )

    with open(args.readme, "w", encoding="utf-8") as readme_file:
        readme_file.write(readme)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, urllib.error.URLError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
