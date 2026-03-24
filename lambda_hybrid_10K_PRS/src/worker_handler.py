#!/usr/bin/env python3

import importlib
import json
import os
import uuid
from datetime import datetime, timezone

boto3 = importlib.import_module("boto3")
botocore_exceptions = importlib.import_module("botocore.exceptions")

ClientError = botocore_exceptions.ClientError


dynamodb = boto3.resource("dynamodb")
s3_client = boto3.client("s3")

TABLE_NAME = os.environ["REQUESTS_TABLE"]
BUCKET_NAME = os.environ["PAYLOAD_BUCKET"]
table = dynamodb.Table(TABLE_NAME)


def _parse_message(record):
    body = record.get("body", "")
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {"raw_body": body}


def _store_payload(request_id, payload):
    timestamp = datetime.now(timezone.utc).isoformat()
    object_key = f"async/{request_id}.json"

    s3_client.put_object(
        Bucket=BUCKET_NAME,
        Key=object_key,
        Body=json.dumps(payload).encode("utf-8"),
        ContentType="application/json",
    )

    table.update_item(
        Key={"id": request_id},
        UpdateExpression="SET s3_key = :s3_key, #status = :status, completed_at = :completed_at",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":s3_key": object_key,
            ":status": "completed",
            ":completed_at": timestamp,
        },
    )


def _claim_request(request_id, timestamp):
    try:
        table.put_item(
            Item={
                "id": request_id,
                "processing_mode": "async",
                "received_at": timestamp,
                "status": "processing",
            },
            ConditionExpression="attribute_not_exists(id)",
        )
        return True
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return False
        raise


def _mark_failed(request_id, error_message):
    table.update_item(
        Key={"id": request_id},
        UpdateExpression="SET #status = :status, error_message = :error_message",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "failed",
            ":error_message": error_message[:500],
        },
    )


def handler(event, _context):
    failures = []

    for record in event.get("Records", []):
        request_id = record.get("messageId") or str(uuid.uuid4())
        try:
            payload = _parse_message(record)
            request_id = payload.get("request_id") or request_id

            if not _claim_request(request_id, datetime.now(timezone.utc).isoformat()):
                continue

            _store_payload(request_id, payload)
        except (ClientError, KeyError, TypeError, ValueError) as error:
            _mark_failed(request_id, str(error))
            failures.append({"itemIdentifier": record.get("messageId", request_id)})

    return {"batchItemFailures": failures}