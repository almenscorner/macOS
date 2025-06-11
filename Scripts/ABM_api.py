import datetime as dt
import uuid
import requests
from authlib.jose import jwt
from Crypto.PublicKey import ECC
from typing import Literal, Optional
from pprint import pprint

TYPE = "business"  # Defaults to ABM, set to "school" for ASM
LIMIT = 100  # Max number of items per page for Apple Business Manager API
API_URL = f"https://api-{TYPE}.apple.com/v1"
PRIVATE_KEY_FILE = "private-key.pem"
CLIENT_ID = ""
TEAM_ID = ""
KEY_ID = ""


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


def request_token(client_assertion: str, client_id: str) -> str:
    """Request an access token from Apple Business Manager API.

    Args:
        client_assertion (str): JWT token for authentication.
        client_id (str): Client ID for the Apple Business Manager API.

    Returns:
        str: Access token as a string.
    """
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
    return response.json().get("access_token")


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
