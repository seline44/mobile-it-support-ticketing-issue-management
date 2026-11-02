import json
import os
import re
from urllib.error import HTTPError, URLError
from urllib.request import Request
from urllib.request import urlopen


def send_meta_whatsapp_message(
    phone_number_id: str,
    recipient: str,
    message: str,
) -> None:
    access_token = os.getenv("META_ACCESS_TOKEN")
    if not access_token:
        raise RuntimeError("META_ACCESS_TOKEN is not configured.")

    api_version = os.getenv("META_GRAPH_API_VERSION", "v23.0")
    if not re.fullmatch(r"v\d+\.\d+", api_version):
        raise RuntimeError("META_GRAPH_API_VERSION must look like v23.0.")

    payload = json.dumps(
        {
            "messaging_product": "whatsapp",
            "to": recipient,
            "type": "text",
            "text": {"body": message},
        }
    ).encode("utf-8")
    request = Request(
        f"https://graph.facebook.com/{api_version}/{phone_number_id}/messages",
        data=payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(request, timeout=10) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(
                    f"Meta WhatsApp API returned HTTP {response.status}."
                )
    except (HTTPError, URLError) as error:
        raise RuntimeError("Meta WhatsApp API request failed.") from error
