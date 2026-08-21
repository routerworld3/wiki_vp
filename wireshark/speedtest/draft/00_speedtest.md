For a public GitHub file, use `curl -L` because GitHub commonly redirects downloads.

To **download the file and see the transfer speed**:

```bash
curl -L -O https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/to/file.zip
```

`curl` will show progress including average/current download speed.

For a cleaner speed test:

```bash
curl -L -o /dev/null \
  -w "Downloaded: %{size_download} bytes\nAverage Speed: %{speed_download} bytes/sec\nTotal Time: %{time_total} sec\n" \
  https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/to/file.zip
```

Example:

```bash
curl -L -o /dev/null \
  -w "Average Speed: %{speed_download} bytes/sec\nTotal Time: %{time_total} sec\n" \
  https://raw.githubusercontent.com/hashicorp/terraform/main/README.md
```

If you want the speed displayed in **MB/sec**, on Linux you can do:

```bash
curl -L -o /dev/null \
  -w "%{speed_download}\n" \
  https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/file \
  | awk '{printf "Download Speed: %.2f MB/s\n", $1/1024/1024}'
```

For a **GitHub Release asset**, use the release download URL:

```bash
curl -L -o testfile.zip \
  -w "\nSpeed: %{speed_download} bytes/sec\nTime: %{time_total} sec\n" \
  https://github.com/OWNER/REPO/releases/download/v1.0/testfile.zip
```

### Useful troubleshooting command

If you're testing GitHub download performance from an EC2/RHEL server, this is particularly useful:

```bash
curl -L -o /dev/null \
  -w "\nHTTP Code: %{http_code}\nRemote IP: %{remote_ip}\nDNS: %{time_namelookup}s\nTCP Connect: %{time_connect}s\nTLS: %{time_appconnect}s\nFirst Byte: %{time_starttransfer}s\nTotal: %{time_total}s\nSpeed: %{speed_download} bytes/sec\n" \
  https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/file
```

That lets you distinguish **DNS, TCP, TLS, server response, and actual download throughput** rather than seeing only one overall speed number.
