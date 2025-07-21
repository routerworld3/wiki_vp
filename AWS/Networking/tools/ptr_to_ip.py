import ipaddress
import dns.resolver
import dns.reversename
import time
import random
import csv

def query_ptr(ip):
    """
    Perform a reverse DNS lookup (PTR query) for a given IPv4 address.

    Args:
        ip (str): The IPv4 address to query.

    Returns:
        list: A list of PTR domain names associated with the IP, or empty if none.
    """
    try:
        # Convert IP to reverse DNS format (e.g., 8.8.8.8 → 8.8.8.8.in-addr.arpa)
        rev_name = dns.reversename.from_address(ip)

        # Query PTR record using system DNS resolver
        answers = dns.resolver.resolve(rev_name, 'PTR')

        # Return a list of domain names (stripped of trailing dots)
        return [str(rdata).rstrip('.') for rdata in answers]
    except (dns.resolver.NXDOMAIN, dns.resolver.NoAnswer):
        return []  # No PTR record found
    except Exception as e:
        print(f"[!] Error for {ip}: {e}")
        return []

def scan_ip_range(ip_range):
    """
    Scan a CIDR-formatted IPv4 range for PTR records.

    Args:
        ip_range (str): The input IP range (e.g., "8.8.8.0/29").

    Returns:
        list of lists: Each inner list contains an IP followed by its PTR results.
    """
    results = []

    try:
        ips = list(ipaddress.IPv4Network(ip_range))
    except ValueError as e:
        print(f"[!] Invalid IP range: {e}")
        return results

    for ip in ips:
        ip_str = str(ip)
        domains = query_ptr(ip_str)

        if domains:
            print(f"[+] {ip_str} → {', '.join(domains)}")
        else:
            print(f"[-] {ip_str} → No PTR record")

        # Store result: IP followed by all PTR domains (or empty list)
        results.append([ip_str] + domains)

        # Random sleep (1–3s) to avoid DNS rate limiting or suspicion
        time.sleep(random.uniform(1, 3))

    return results

def write_csv(data, output_file):
    """
    Write IP-to-PTR results to a CSV file. Each PTR domain goes in its own column.

    Args:
        data (list of lists): Output from scan_ip_range().
        output_file (str): Path to the CSV file to write.
    """
    # Determine the maximum number of PTR domains any IP returned
    max_ptrs = max(len(row) - 1 for row in data) if data else 0

    # Construct headers: IP, Domain_1, Domain_2, ...
    headers = ['IP'] + [f'Domain_{i+1}' for i in range(max_ptrs)]

    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(headers)

        for row in data:
            # Pad with empty strings if this row has fewer PTRs
            padded_row = row + [''] * (max_ptrs - len(row) + 1)
            writer.writerow(padded_row)

if __name__ == "__main__":
    # Prompt user for IP range input (CIDR format)
    ip_range_input = input("Enter IP range (CIDR, e.g. 8.8.8.0/29): ").strip()

    # Perform scan and capture results
    results = scan_ip_range(ip_range_input)

    # Save to CSV
    output_file = "ptr_results.csv"
    write_csv(results, output_file)

    print(f"\n✅ Scan complete. Results saved to '{output_file}'")
