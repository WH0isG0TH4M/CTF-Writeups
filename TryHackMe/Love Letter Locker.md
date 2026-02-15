# Love Letter Locker – TryHackMe Write-Up

## Challenge Overview

In this new challenge of TryHackMe named **Love Letter Locker**, the goal is to:

> "Use your skills to access other users' letters."

This suggests that the application may contain an **IDOR (Insecure Direct Object Reference)** vulnerability.

---

## 🌐 Accessing the Application

The web application is accessible at:

```bash
http://TARGET_IP:5000

I visited the website, registered a new account with the username hacker, and successfully logged in.

After logging in, I noticed the following message:
Total letters in Cupid’s archive: 2
This indicates that there are already two love letters stored in the application.

## Testing for IDOR

To test the functionality, I created a new letter.

After submitting it, I noticed that the URL contained the ID number of my letter: /letter/3

Since the archive previously showed 2 letters, and my new letter was assigned ID 3, it suggests that the IDs are sequential.

I then manually modified the URL from: /letter/3 to /letter/1

After changing the ID to 1, I was able to view another user's letter, which revealed the flag.

#🚨 Vulnerability Explanation

This confirms that the application is vulnerable to IDOR (Insecure Direct Object Reference) because:

Letter IDs are predictable and sequential.

There is no authorization check to verify ownership.

Any authenticated user can change the ID in the URL to access other users' letters.

This allows unauthorized access to sensitive user data.
