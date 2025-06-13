#!/usr/bin/env python3

"""
This script interacts with the Apple Business Manager API to retrieve device and organization information.
It uses JWT for authentication and caches the access token to avoid frequent re-authentication.
It supports pagination for API responses and can handle both GET and POST requests.
It is designed to work with both Apple Business Manager (ABM) and Apple School Manager (ASM) by changing the TYPE variable.
It requires the `authlib`, `requests`, and `pycryptodome` libraries for JWT creation and HTTP requests.
It is important to ensure that the private key file, client ID, team ID, and key ID are correctly set for your Apple Business Manager or Apple School Manager account.

Written by Tobias Almén
"""

import os
import datetime as dt
import uuid
import json
import requests

from argparse import ArgumentParser
from time import sleep, time
from typing import Literal, Optional, Tuple
from pprint import pprint
from authlib.jose import jwt
from Crypto.PublicKey import ECC

TOKEN_CACHE_FILE = ".token_cache"

PRIVATE_KEY_FILE = os.environ.get("PRIVATE_KEY_FILE")
CLIENT_ID = os.environ.get("CLIENT_ID")
TEAM_ID = os.environ.get("TEAM_ID")
KEY_ID = os.environ.get("KEY_ID")

if not all([PRIVATE_KEY_FILE, CLIENT_ID, TEAM_ID, KEY_ID]):
    raise ValueError(
        "Please set PRIVATE_KEY_FILE, CLIENT_ID, TEAM_ID, and KEY_ID variables."
    )


def parse_args() -> ArgumentParser:
    """Parse command line arguments."""
    parser = ArgumentParser(description="Apple Business Manager API Client")
    parser.add_argument(
        "--type",
        choices=["business", "school"],
        default="business",
        help="Type of Apple service to use (business or school). Defaults to 'business'.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=100,
        help="Maximum number of items per page. Defaults to 100.",
    )
    return parser.parse_args()


args = parse_args()

TYPE = args.type
LIMIT = args.limit
API_URL = f"https://api-{TYPE}.apple.com/v1"


def create_jwt(
    private_key_file: str,
    client_id: str,
    team_id: str,
    key_id: str,
    audience: str = "https://account.apple.com/auth/oauth2/v2/token",
    alg: str = "ES256",
) -> str:
    """Create a JWT for Apple Business Manager API authentication.

    Returns:
        str: A JWT token as a string.
    """
    issued_at = int(dt.datetime.now(dt.UTC).timestamp())
    expires_at = issued_at + 86400 * 180  # max 180 days

    headers = {"alg": alg, "kid": key_id}
    payload = {
        "sub": client_id,
        "aud": audience,
        "iat": issued_at,
        "exp": expires_at,
        "jti": str(uuid.uuid4()),
        "iss": team_id,
    }

    with open(private_key_file, "rt", encoding="UTF8") as file:
        private_key = ECC.import_key(file.read())

    jwt_token = jwt.encode(
        header=headers, payload=payload, key=private_key.export_key(format="PEM")
    ).decode("utf-8")

    return jwt_token


def cache_token(
    token: str, expires_in: int, cache_file: str = TOKEN_CACHE_FILE
) -> None:
    """Cache the access token to a file.

    Args:
        token (str): Access token to cache.
        cache_file (str): File path to store the cached token.
    """
    expires_at = time() + int(expires_in * 0.75)  # add safety margin
    cache_data = {"token": token, "expires_at": expires_at}
    with open(cache_file, "w", encoding="UTF8") as file:
        json.dump(cache_data, file)


def load_cached_token(
    cache_file: str = TOKEN_CACHE_FILE,
) -> Optional[Tuple[str, float]]:
    """Load the cached token and expiration time."""
    try:
        with open(cache_file, "r", encoding="UTF8") as file:
            data = json.load(file)
            return data["token"], data["expires_at"]
    except (FileNotFoundError, KeyError, json.JSONDecodeError):
        return None


def is_token_valid(expires_at: float) -> bool:
    """Return True if current time is before the expiration timestamp."""
    return time() < expires_at


def request_token(client_assertion: str, client_id: str) -> str:
    """Request an access token from Apple Business Manager API.

    Args:
        client_assertion (str): JWT token for authentication.
        client_id (str): Client ID for the Apple Business Manager API.

    Returns:
        str: Access token as a string.
    """
    # Check if a cached token exists
    cached = load_cached_token()
    print("Checking for cached token...")
    if cached:
        print("Cached token found.")
        cached_token, expiration = cached
        if is_token_valid(expiration):
            print("Cached token is valid. Using cached token.")
            print(f"Token expires at: {dt.datetime.fromtimestamp(expiration)}")
            return cached_token
        else:
            print("Cached token expired. Requesting a new token.")

    print("Requesting new token.")
    token_url = "https://account.apple.com/auth/oauth2/token"
    data = {
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        "client_assertion": client_assertion,
        "scope": f"{TYPE}.api",
    }

    response = requests.post(token_url, data=data, timeout=10)
    response.raise_for_status()

    response_data = response.json()
    token = response_data.get("access_token")
    expires_in = response_data.get("expires_in")

    if token and expires_in:
        cache_token(token, expires_in)
        return token
    else:
        raise RuntimeError("Failed to retrieve token or expiration from response.")


def make_api_request(
    url: str,
    token: str,
    method: Literal["GET", "POST"] = "GET",
    payload: Optional[dict] = None,
    query_params: Optional[dict] = None,
) -> list:
    """Fetch all pages of results from the Apple Business Manager API.

    Args:
        url (str): The initial URL to fetch data from.
        token (str): Access token for authentication.
        method (Literal[&quot;GET&quot;, &quot;POST&quot;], optional): HTTP method to use for the request. Defaults to "GET".
        payload (Optional[dict], optional): Payload for POST requests. Defaults to None.
        query_params (Optional[dict], optional): Query parameters for the request. Defaults to None.

    Returns:
        list: A list containing all results from the paginated API response.
    """
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }

    all_results = []

    while url:
        if method == "GET":
            response = requests.get(
                url, headers=headers, timeout=120, params=query_params
            )
        else:
            response = requests.post(url, headers=headers, json=payload, timeout=120)

        retry_count = 0
        while response.status_code != 200 and retry_count < 5:
            print(
                f"Request failed with status code {response.status_code}. Retrying..."
            )
            response = requests.get(
                url, headers=headers, timeout=120, params=query_params
            )
            retry_count += 1
            sleep(5)

        response.raise_for_status()
        data = response.json()

        if isinstance(data, dict) and "data" in data:
            all_results.extend(data["data"])
        else:
            all_results.append(data)

        url = data.get("links", {}).get("next")

    return all_results


JWT = create_jwt(PRIVATE_KEY_FILE, CLIENT_ID, TEAM_ID, KEY_ID)
access_token = request_token(JWT, CLIENT_ID)
# query_params = {"fields": "serialNumber"}

devices = make_api_request(
    url=f"{API_URL}/orgDevices?limit={LIMIT}",
    token=access_token,
    # query_params=query_params,
)

print(f"Found {len(devices)} devices.")

for device in devices:
    pprint(device["attributes"])
    print("\n")
