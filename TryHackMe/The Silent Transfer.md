# Room: The Silent Transfer

Difficulty: Easy

This challenge assumes that you can filter packet captures, work with Zeek logs, and pivot between related network events. The following rooms are recommended before you begin:

- Traffic Analysis Pitfalls
- Detection Engineering with Snort
- Network Security Monitoring with Zeek
- Threat Hunting with Zui
- Advanced Packet Analysis

All evidence is stored in /home/ubuntu/capstone/:

- snort_alerts.log — Snort detection output
- zeek_logs/ — Zeek connection, DNS, TLS, HTTP, file, and notice logs
- investigation.pcap — Packet capture for packet-level validation
- fortigate_traffic.log — Firewall traffic covering internal and cross-subnet activity
- references/ — Local threat intelligence and MITRE ATT&CK reference material

## Operation SILENT TRANSFER — Capstone Investigation

### Storyline 
A Snort alert has fired on WKST-DEV-12 (10.14.30.88) in the
Developer subnet at 03:47:22 UTC on 2025-11-14. The alert message is
"ET TROJAN Possible Cobalt Strike Beacon CnC Activity - GET Checkin".

This host was NOT visible to the Finance subnet investigation you have
been working on in Rooms 1-5. This is a new dataset from a separate
perimeter sensor covering the Developer subnet (10.14.30.0/24) and the
internal server segment (10.14.0.0/24).

Your evidence set:

- snort_alerts.log     — All Snort alerts, 02:00–06:00 UTC
- zeek_logs/           — Zeek log set for the Developer subnet perimeter
- fortigate_traffic.log — Fortigate UTM log, all subnets, 02:00–06:00 UTC
- investigation.pcap   — Full PCAP from the Developer subnet sensor
- references/          — Local threat intelligence, MITRE quickref, JA4 reference

Outbound network is disabled. Everything you need to answer the 15
investigation questions is in this directory.

Begin with the alert. Decide which log to consult next.

### Q1. Review the detection evidence around 03:47 UTC and correlate it with the repeated C2 traffic. Which internal IP address originated that traffic?

To find the IP address for this task, I used snort_alerts.log because the detection occurred around 03:47 UTC, and the log contains alerts from 02:00–06:00 UTC.

I filtered the file using the following command:
``` bash
cat snort_alerts.log | grep "03:47:22"
```
Result:
``` bash
11/14-03:47:22.543210 [**] [1:2023476:4] ET TROJAN Possible Cobalt Strike Beacon CnC Activity - GET Checkin [**] [Classification: A Network Trojan was detected] [Priority: 1] {TCP} 10.14.30.88:51088 -> 194.165.16.56:443
```
### Answer: 10.14.30.88

### Q2. Working backwards from the C2 activity, which domain was used to deliver the initial dropper to the compromised workstation?

To identify the C2 server, I checked dns.log for DNS activity associated with the 194.165.16.0/24 network.

I used the following command:
``` bash
cat dns.log | grep "194.165.16\."
```
Result:
``` bash
1763081100.000000	CL0WJ4FF1U10fKQrGh	10.14.30.88	52150	10.14.0.53	53	udp	19795	0.005234	cdn-updates.microsoftservice.net	1	C_INTERNET	1	A	0	NOERROR	F	F	T	T	0	194.165.16.78	300.000000	F
```
### Answer: cdn-updates.microsoftservice.net

### Q3. Identify the file downloaded from the delivery domain. What is its SHA256 hash?

To find the SHA256 hash of the downloaded file, I used files.log and filtered for the same external IP address:
``` bash
cat files.log | grep "194.165.16\."
```
Result:
``` bash
1763081220.000000	FHGphAnTbrPGRrMmu9	194.165.16.78	10.14.30.88	CrD5UMpFW617XYhqtK	HTTP	0	SHA256,MD5,SHA1	application/x-dosexec	winservice-patch-4891.exe	8.500000	F	F	1887232	1887232	0	0	F	-	a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6	abcdef1234567890abcdef1234567890abcdef12	7f3b2e1a9c8d4f5e6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f90	-	F	0
```
The downloaded file was winservice-patch-4891.exe.

### Answer: 7f3b2e1a9c8d4f5e6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f90

### Q4. Which source port did the compromised workstation use for its first connection to the C2 server?

I used conn.log to find the first connection from the compromised workstation to the C2 server.

I used the following command:
``` bash
cat conn.log | grep "194.165.16.56" | head -n 1
```
This displays the first matching connection.

Result:
``` bash
1763083380.000000	CDhMvog1ELRT522A0A	10.14.30.88	51000	194.165.16.56	443	tcp	ssl	1.800825	1183	231	SF	T	F	0	ShADadfF	3	1303	1	271
```
The source port used by the compromised workstation was 51000.

### Answer: 51000

### Q5. Review the TLS activity between the compromised workstation and the C2 server. What JA4 fingerprint identifies the C2 client?

I used ssl.log to find the JA4 fingerprint associated with the C2 connection.

I used the following command:
``` bash
cat ssl.log | grep "194.165.16.56" | head -n 1
```
Result:
``` bash
1763083380.000000	CDhMvog1ELRT522A0A	10.14.30.88	51000	194.165.16.56	443	TLSv13	TLS_AES_256_GCM_SHA384	x25519	-F-	h2	T	ChSsNsc	-	-	F	self signed certificate	t13d190900_9dc949149365_97f8aa674fd9
```
### Answer: t13d190900_9dc949149365_97f8aa674fd9

### Q6. After C2 was established, how many unique internal destination IP addresses did the compromised workstation contact during its SMB discovery activity?

I used fortigate_traffic.log to count the unique internal destination IP addresses contacted over SMB.

I used the following command:
``` bash
grep "10.14.30.88" fortigate_traffic.log | grep -E "dstport=445|dstport=139|srcport=445|srcport=139" | grep -oE "dstip=[0-9]+.[0-9]+.[0-9]+.[0-9]+" | sort -u | wc -l
```
This command:

- Filters the logs for the compromised workstation.
- Narrows the results to SMB ports (445 and 139).
- Extracts the destination IP addresses.
- Removes duplicate IP addresses.
- Counts the remaining unique destination IP addresses.

### Answer: 23

### Q7. Following the SMB activity, the attacker established an RDP connection to an internal server. What is the destination IP address?

To find the destination IP address, I searched fortigate_traffic.log for traffic using destination port 3389, which is the default port for RDP.

I used:
``` bash
grep -E "dstport=3389" fortigate_traffic.log | grep "10.14.30.88"
```
Result:
``` bash
date=2025-11-14 time=02:22:00 devname="FW-DEV-01" devid="FGT60E4Q17000000" logid="0000000013" type="traffic" subtype="forward" level="notice" vd="root" eventtime=1763086920 srcip=10.14.30.88 srcport=51234 srcintf="dev-lan" srcintfrole="lan" dstip=10.14.0.12 dstport=3389 dstintf="srv-lan" dstintfrole="lan" sessionid=433096 proto=6 action="accept" policyid=5 policytype="policy" service="RDP" dstcountry="Reserved" srccountry="Reserved" duration=420 sentbyte=512000 rcvdbyte=2097152 sentpkt=365 rcvdpkt=1497
```
The destination IP address is 10.14.0.12.

### Answer: 10.14.0.12

### Q8. Review the DNS activity originating from the RDP destination. Which domain did the server resolve immediately before the large outbound transfer?

I returned to dns.log to review DNS activity originating from 10.14.0.12.

I used:
``` bash
cat dns.log | grep "10.14.0.12"
```
The log contained several entries, so I reviewed the relevant DNS activity associated with the server.

### Answer: backup.corpfiles-sync.com

### Q9. Identify the archive transferred from the internal server to the external endpoint. What is its SHA256 hash?

I found the SHA256 hash in files.log by filtering for the internal server's IP address:
``` bash
cat files.log | grep "10.14.0.12"
```
Result:
``` bash
1763091720.000000	FDd9J8z0g5eQHh7NYx	10.14.0.12	185.213.154.201	CHQztwtwi2Jkq87YgB	HTTP	0	SHA256,MD5,SHA1	application/zip	Q4-Finance-Backup-2025.zip	480.000000	T	T	312447821	312447821	0	0	F	-b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7	1234567890abcdef1234567890abcdef12345678	a3f8e2c1d4b7a9e0f2c3d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6	-	F	0
```
The archive transferred was Q4-Finance-Backup-2025.zip.

### Answer: a3f8e2c1d4b7a9e0f2c3d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6

### Q10. Inspect the application-layer contents of the C2 traffic. What command did the attacker issue to the compromised workstation?

Since I needed to inspect the application-layer contents of the C2 traffic, I used Wireshark and filtered the traffic using HTTP.

I found a packet containing:
```
GET /api/v2/check HTTP/1.1
Host: update.softpatch-cdn.com
User-Agent: Mozilla/5.0
Accept: */*

The server responded with:

HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 38
Connection: keep-alive

{"status":"ok","cmd":"","interval":60}
```
I reviewed each TCP stream until I found TCP stream 23, which contained a Base64-encoded command:
```
{"status":"ok","cmd":"d2hvYW1p","interval":60}
```
After decoding the Base64 value d2hvYW1p, it translates to:

whoami

### Answer: whoami
