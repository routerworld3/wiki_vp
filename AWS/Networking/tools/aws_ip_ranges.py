import requests
import json
import csv
from collections import defaultdict
from ipaddress import ip_network

# URL for AWS IP ranges JSON
AWS_IP_RANGES_URL = "https://ip-ranges.amazonaws.com/ip-ranges.json"
STATIC_JSON_PATH = "ip-ranges.json"
OUTPUT_CSV = "aws_ip_ranges_by_region.csv"

def fetch_aws_ip_ranges():
    try:
        print(f"Fetching from {AWS_IP_RANGES_URL}")
        response = requests.get(AWS_IP_RANGES_URL)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Failed to fetch live data: {e}")
        print(f"Using static fallback: {STATIC_JSON_PATH}")
        with open(STATIC_JSON_PATH, "r") as f:
            return json.load(f)

def process_ip_ranges(data):
    region_map = defaultdict(list)
    for entry in data.get("prefixes", []):
        region = entry.get("region", "unknown")
        ip_prefix = entry.get("ip_prefix")
        service = entry.get("service", "unknown")
        if ip_prefix:
            region_map[region].append((ip_prefix, service))

    # Sort IP prefixes within each region using ip_network
    for region in region_map:
        region_map[region].sort(key=lambda x: ip_network(x[0]))

    return region_map

def write_csv(region_map):
    with open(OUTPUT_CSV, mode="w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(["region", "ip_prefix", "service"])
        for region in sorted(region_map.keys()):
            for ip_prefix, service in region_map[region]:
                writer.writerow([region, ip_prefix, service])
    print(f"CSV written to {OUTPUT_CSV}")

def main():
    data = fetch_aws_ip_ranges()
    region_map = process_ip_ranges(data)
    write_csv(region_map)

if __name__ == "__main__":
    main()
