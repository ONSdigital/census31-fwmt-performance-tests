"""Pub/Sub publisher for the Job Service perf rig.

Publishes field-worker instructions to the Google Pub/Sub emulator over the REST
API. Message attributes carry the ``__TypeId__`` discriminator the job-service
codec requires (see census31-fwmt-common FieldWorkerInstructionJsonCodec).
"""

import base64
import json
import time
import urllib.error
import urllib.parse
import urllib.request

from config import Config as cfg, pubsub_api_base

# Type ids accepted by census31-fwmt-common FieldWorkerInstructionJsonCodec.
TYPE_ID_CREATE = "uk.gov.ons.census.fwmt.common.rm.dto.FwmtActionInstruction"
TYPE_ID_CANCEL = "uk.gov.ons.census.fwmt.common.rm.dto.FwmtCancelActionInstruction"

CONTENT_TYPE_JSON = "application/json"


class PubSubPublisher:
    """Publishes to the configured Pub/Sub emulator topic over the REST API."""

    def __init__(self):
        self._topic = cfg.PUBSUB_TOPIC
        self._publish_url = "{base}/topics/{topic}:publish".format(
            base=pubsub_api_base(),
            topic=urllib.parse.quote(self._topic, safe=""),
        )

    def publish(self, type_id, body, timestamp_ms=None):
        if timestamp_ms is None:
            timestamp_ms = int(round(time.time() * 1000))
        attributes = {
            "__TypeId__": type_id,
            "content_type": CONTENT_TYPE_JSON,
            "timestamp": str(timestamp_ms),
        }
        envelope = {
            "messages": [
                {
                    "data": base64.b64encode(body.encode("utf-8")).decode("ascii"),
                    "attributes": attributes,
                }
            ]
        }
        payload = json.dumps(envelope).encode("utf-8")
        request = urllib.request.Request(
            self._publish_url,
            data=payload,
            headers={"Content-Type": CONTENT_TYPE_JSON},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                "Pub/Sub publish to topic '{topic}' failed: HTTP {code} {detail}".format(
                    topic=self._topic, code=exc.code, detail=detail
                )
            ) from exc

    def close(self):
        pass


def get_publisher():
    """Return the Pub/Sub publisher for the configured emulator topic."""
    return PubSubPublisher()
