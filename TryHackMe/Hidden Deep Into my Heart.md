# Hidden Deep Into my Heart 💘
Category: Web / Reconnaissance

Objective: Uncover the secret hidden inside Cupid's Vault.

Challenge Description:
``` html
My Dearest Hacker,

Cupid's Vault was designed to protect secrets meant to stay hidden forever.

Unfortunately, Cupid underestimated how determined attackers can be.

Intelligence indicates that Cupid may have unintentionally left vulnerabilities in

the system. With the holiday deadline approaching, you've been tasked

with uncovering what's hidden inside the vault before it's too late.

You can find the web application here: http://TARGET_IP:5000
```
# 🕵️ Phase 1: Reconnaissance
The landing page presented a "Love Letters Anonymous" message board. Since there were no obvious interactive elements, I started a directory brute-force attack using ffuf to find hidden files.

## Directory Discovery
I discovered a robots.txt file, which is often a goldmine for restricted paths.
``` plaintext
User-agent: *
Disallow: /cupids_secret_vault/*

# cupid_arrow_2026!!!
```
Key Finding: The file revealed a restricted directory /cupids_secret_vault/ and a potential credential string: cupid_arrow_2026!!!.
# 🔍 Phase 2: Enumerating the Vault
Navigating to 
``` html 
http://TARGET_IP:5000/cupids_secret_vault/ 
```
confirmed the directory existed, but the page simply stated: "You've found the secret vault, but there's more to discover..."
I ran a second ffuf scan specifically on this subdirectory to find the actual entry point and found  
``` plaintext 
/cupids_secret_vault/administrator 
```
This led to a hidden administrative login portal.
# 🔑 Phase 3: Exploitation & Authentication
With a login page found and a potential password from the robots.txt comments, I attempted a credential spray.

Username: admin (Common default)

Password: cupid_arrow_2026!!!

The credentials were valid, granting access to the internal dashboard and revealing the hidden flag.

# 💡 Lessons Learned
Robots.txt isn't Security: Never use robots.txt to hide sensitive directories; it acts as a map for attackers.

Comment Hygiene: Developers should never leave passwords or sensitive hints in configuration file comments.

Recursive Scanning: Always scan subdirectories found during the initial recon phase.
