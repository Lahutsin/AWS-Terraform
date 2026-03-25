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
STACK_NAME = os.environ.get("STACK_NAME", "lambda-hybrid")
table = dynamodb.Table(TABLE_NAME)


def _parse_body(event):
    body = event.get("body")
    if not body:
        return {}

    if isinstance(body, dict):
        return body

    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {"raw_body": body}


def _claim_request(request_id, timestamp):
    try:
        table.put_item(
            Item={
                "id": request_id,
                "processing_mode": "sync",
                "received_at": timestamp,
                "status": "processing",
                "lane": "sync",
            },
            ConditionExpression="attribute_not_exists(id)",
        )
        return True
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return False
        raise


def _load_existing_request(request_id):
    response = table.get_item(Key={"id": request_id})
    return response.get("Item", {})


def _mark_completed(request_id, object_key, timestamp, payload):
    table.update_item(
        Key={"id": request_id},
        UpdateExpression=(
            "SET s3_key = :s3_key, #status = :status, completed_at = :completed_at, "
            "payload_type = :payload_type, stack_name = :stack_name"
        ),
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":s3_key": object_key,
            ":status": "completed",
            ":completed_at": timestamp,
            ":payload_type": payload.get("type", "sync"),
            ":stack_name": STACK_NAME,
        },
    )


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
    payload = _parse_body(event)
    request_id = payload.get("request_id") or event.get("requestContext", {}).get("requestId") or str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()
    object_key = f"sync/{request_id}.json"

    if not _claim_request(request_id, timestamp):
        existing_item = _load_existing_request(request_id)
        return {
            "statusCode": 200,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(
                {
                    "message": "request already processed",
                    "request_id": request_id,
                    "duplicate": True,
                    "existing": existing_item,
                }
            ),
        }

    try:
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=object_key,
            Body=json.dumps(payload).encode("utf-8"),
            ContentType="application/json",
            Metadata={"request-id": request_id, "lane": "sync"},
        )

        _mark_completed(request_id, object_key, datetime.now(timezone.utc).isoformat(), payload)
    except (ClientError, TypeError, ValueError) as error:
        _mark_failed(request_id, str(error))
        raise

    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(
            {
                "message": "request processed synchronously",
                "request_id": request_id,
                "table": TABLE_NAME,
                "bucket": BUCKET_NAME,
                "key": object_key,
                "duplicate": False,
            }
        ),
    }