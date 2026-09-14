import json
import os
import urllib.parse
import boto3


# ============================================================
# AWS CLIENTS
# ============================================================

s3 = boto3.client("s3")


# ============================================================
# ENVIRONMENT VARIABLES
# ============================================================

APPROVED_PREFIX = os.environ.get("APPROVED_PREFIX", "approved/")
REJECTED_PREFIX = os.environ.get("REJECTED_PREFIX", "rejected/")


# ============================================================
# ALLOWED DOCUMENT TYPES
# ============================================================

ALLOWED_EXTENSIONS = {
    ".pdf",
    ".docx",
    ".txt",
    ".md"
}


# ============================================================
# LAMBDA ENTRY POINT
# ============================================================

def lambda_handler(event, context):

    print("Received event:")
    print(json.dumps(event))

    results = []

    # --------------------------------------------------------
    # S3 can send multiple records in one event.
    # Process each record independently.
    # --------------------------------------------------------

    for record in event.get("Records", []):

        try:
            result = process_s3_record(record)
            results.append(result)

        except Exception as error:

            print(f"Error processing record: {error}")

            results.append({
                "status": "error",
                "error": str(error)
            })

    return {
        "statusCode": 200,
        "body": json.dumps({
            "processed": results
        })
    }


# ============================================================
# PROCESS ONE S3 EVENT
# ============================================================

def process_s3_record(record):

    bucket_name = record["s3"]["bucket"]["name"]

    object_key = urllib.parse.unquote_plus(
        record["s3"]["object"]["key"]
    )

    print(f"Processing: s3://{bucket_name}/{object_key}")

    # --------------------------------------------------------
    # Only process documents arriving in incoming/.
    # This prevents the Lambda from processing its own
    # approved/ or rejected/ output.
    # --------------------------------------------------------

    if not object_key.startswith("incoming/"):

        print(
            f"Skipping object outside incoming/ prefix: "
            f"{object_key}"
        )

        return {
            "status": "skipped",
            "reason": "Object is outside incoming/ prefix",
            "key": object_key
        }

    # --------------------------------------------------------
    # Ignore folder marker objects.
    # --------------------------------------------------------

    if object_key.endswith("/"):

        return {
            "status": "skipped",
            "reason": "Folder marker",
            "key": object_key
        }

    # --------------------------------------------------------
    # Validate file extension.
    # --------------------------------------------------------

    extension = get_file_extension(object_key)

    if extension not in ALLOWED_EXTENSIONS:

        return reject_document(
            bucket_name,
            object_key,
            f"Unsupported document type: {extension}"
        )

    # --------------------------------------------------------
    # Read the uploaded document metadata.
    # --------------------------------------------------------

    metadata = get_object_metadata(
        bucket_name,
        object_key
    )

    print(f"Document metadata: {metadata}")

    # --------------------------------------------------------
    # Validate approval status.
    #
    # Other metadata such as category, owner, version,
    # effective-date, and review-date is optional.
    # --------------------------------------------------------

    validation_error = validate_metadata(metadata)

    if validation_error:

        return reject_document(
            bucket_name,
            object_key,
            validation_error
        )

    # --------------------------------------------------------
    # All validation checks passed.
    #
    # Move the document to approved/.
    # --------------------------------------------------------

    approved_key = object_key.replace(
        "incoming/",
        APPROVED_PREFIX,
        1
    )

    copy_document(
        bucket_name,
        object_key,
        approved_key
    )

    delete_document(
        bucket_name,
        object_key
    )

    print(
        f"Document approved: "
        f"s3://{bucket_name}/{approved_key}"
    )

    return {
        "status": "approved",
        "source": object_key,
        "destination": approved_key
    }


# ============================================================
# GET OBJECT EXTENSION
# ============================================================

def get_file_extension(object_key):

    filename = object_key.rsplit("/", 1)[-1]

    if "." not in filename:
        return ""

    return "." + filename.rsplit(".", 1)[-1].lower()


# ============================================================
# GET S3 OBJECT METADATA
# ============================================================

def get_object_metadata(bucket_name, object_key):

    response = s3.head_object(
        Bucket=bucket_name,
        Key=object_key
    )

    return response.get("Metadata", {})


# ============================================================
# VALIDATE DOCUMENT METADATA
# ============================================================

def validate_metadata(metadata):

    # --------------------------------------------------------
    # Only explicit approval is required.
    #
    # Additional governance metadata such as category,
    # owner, version, effective-date, and review-date can
    # be added when available but are not required for
    # document ingestion.
    # --------------------------------------------------------

    approval_status = metadata.get(
        "approval-status",
        ""
    ).strip().lower()

    if approval_status != "approved":

        return (
            "Document must have "
            "approval-status=approved"
        )

    return None


# ============================================================
# COPY DOCUMENT
# ============================================================

def copy_document(
    bucket_name,
    source_key,
    destination_key
):

    s3.copy_object(
        Bucket=bucket_name,

        CopySource={
            "Bucket": bucket_name,
            "Key": source_key
        },

        Key=destination_key
    )


# ============================================================
# DELETE ORIGINAL DOCUMENT
# ============================================================

def delete_document(bucket_name, object_key):

    s3.delete_object(
        Bucket=bucket_name,
        Key=object_key
    )


# ============================================================
# REJECT DOCUMENT
# ============================================================

def reject_document(
    bucket_name,
    object_key,
    reason
):

    rejected_key = object_key.replace(
        "incoming/",
        REJECTED_PREFIX,
        1
    )

    print(
        f"Rejecting document: {object_key}"
    )

    print(
        f"Reason: {reason}"
    )

    # --------------------------------------------------------
    # Copy the document to rejected/.
    # --------------------------------------------------------

    copy_document(
        bucket_name,
        object_key,
        rejected_key
    )

    # --------------------------------------------------------
    # Delete it from incoming/.
    # --------------------------------------------------------

    delete_document(
        bucket_name,
        object_key
    )

    # --------------------------------------------------------
    # Return rejection information.
    # --------------------------------------------------------

    return {
        "status": "rejected",
        "source": object_key,
        "destination": rejected_key,
        "reason": reason
    }
