#!/usr/bin/env python3
"""Print an S3 folder tree using read-only ListObjectsV2 requests.

Examples:
  python3 s3_tree.py my-bucket
  python3 s3_tree.py my-bucket --depth 5 --files
  python3 s3_tree.py my-bucket --prefix AWSLogs/ --region us-gov-west-1

Requires Python 3, boto3, and s3:ListBucket permission on the bucket.
Depth is relative to the selected prefix; 0 means unlimited.
Folders named exactly 2025 or 2026 are shown as [collapsed]; their contents
are not listed, even with --depth 0 or --files.
Only current objects are listed. No objects are downloaded or modified.
Large trees can take time and incur S3 LIST request charges.
"""

import argparse
import json
import sys


COLLAPSED_FOLDERS = {"2025", "2026"}


def display_name(name):
    # Keep unusual object names from adding lines or terminal control sequences.
    return json.dumps(name, ensure_ascii=True)[1:-1]


def children(paginator, bucket, prefix, include_files):
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix, Delimiter="/"):
        entries = [(item["Prefix"], True) for item in page.get("CommonPrefixes", [])]
        if include_files:
            entries.extend(
                (item["Key"], False)
                for item in page.get("Contents", [])
                if item["Key"] != prefix  # Skip the folder-marker object itself.
            )
        for key, is_folder in sorted(entries):
            yield key, is_folder


def print_tree(s3, bucket, prefix, max_depth, include_files):
    paginator = s3.get_paginator("list_objects_v2")
    root_collapsed = any(part in COLLAPSED_FOLDERS for part in prefix.split("/"))
    suffix = " [collapsed]" if root_collapsed else ""
    print(f"s3://{bucket}/{display_name(prefix)}{suffix}", flush=True)
    if root_collapsed:
        return
    # Iterative traversal also supports deeply nested prefixes.
    stack = [(prefix, 1, iter(children(paginator, bucket, prefix, include_files)))]
    while stack:
        parent, level, iterator = stack[-1]
        try:
            key, is_folder = next(iterator)
        except StopIteration:
            stack.pop()
            continue
        name = key[len(parent):]
        collapsed = is_folder and name.removesuffix("/") in COLLAPSED_FOLDERS
        suffix = " [collapsed]" if collapsed else ""
        print("    " * level + display_name(name) + suffix, flush=True)
        if is_folder and not collapsed and (max_depth == 0 or level < max_depth):
            stack.append((key, level + 1, iter(children(paginator, bucket, key, include_files))))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("bucket", help="Bucket name, without s3://")
    parser.add_argument("--prefix", default="", help="Start at this folder, e.g. AWSLogs/")
    parser.add_argument("--depth", type=int, default=3, help="Levels to display (default: 3; 0: unlimited)")
    parser.add_argument("--files", action="store_true", help="Include object names; default is folders only")
    parser.add_argument("--region", help="Bucket region, e.g. us-gov-west-1")
    args = parser.parse_args()
    if args.depth < 0:
        parser.error("--depth must be zero or positive")
    if not args.bucket or "/" in args.bucket:
        parser.error("Supply only the bucket name; use --prefix for a folder")
    prefix = args.prefix
    if prefix and not prefix.endswith("/"):
        prefix += "/"

    try:
        import boto3
        from botocore.exceptions import BotoCoreError, ClientError
    except ImportError:
        print("Install the dependency: python3 -m pip install --user boto3", file=sys.stderr)
        return 1

    try:
        s3 = boto3.client("s3", region_name=args.region)
        print_tree(s3, args.bucket, prefix, args.depth, args.files)
    except (BotoCoreError, ClientError) as exc:
        print(f"Error: {exc}\nThe listing may be incomplete.", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nStopped. The listing may be incomplete.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
