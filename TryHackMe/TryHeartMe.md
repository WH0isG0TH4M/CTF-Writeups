# TryHeartMe Write-up
Challenge Category: Web Exploitation

Difficulty: Easy

Objective: Purchase the hidden "Valenflag" item from the Valentine's gift shop.

# Initial Reconnaissance
Upon navigating to
``` bash
http://TARGET_IP:5000
```
I registered a new account to explore the shop's functionality. The initial dashboard appeared secure, with no obvious injection points or hidden directories visible in the UI.

# Technical Analysis
I intercepted the traffic using Burp Suite to examine how the application handles session management and user permissions.

I identified a cookie named tryheartme_jwt. After decoding the token, I observed the following JSON structure in the payload:
``` JSON
{
  "email": "hacker@gmail.com",
  "role": "user",
  "credits": 0,
  "iat": 1771649911,
  "theme": "valentine"
}
```
Gemini said
That’s a classic JWT (JSON Web Token) manipulation vulnerability! Since you've got the technical steps down, let's polish this into a professional CTF (Capture The Flag) Write-up format.

In the security world, clarity and reproducibility are everything. Here is how you can structure that story:

CTF Write-up: TryHeartMe
Challenge Category: Web Exploitation

Difficulty: Easy/Medium

Objective: Purchase the hidden "Valenflag" item from the Valentine's gift shop.

1. Initial Reconnaissance
Upon navigating to http://TARGET_IP:5000, I registered a new account to explore the shop's functionality. The initial dashboard appeared secure, with no obvious injection points or hidden directories visible in the UI.

2. Technical Analysis
I intercepted the traffic using Burp Suite to examine how the application handles session management and user permissions.

I identified a cookie named tryheartme_jwt. After decoding the token, I observed the following JSON structure in the payload:

JSON
{
  "username": "hacker_user",
  "role": "user",
  "credits": 0
}
# Exploitation (JWT Manipulation)
The application appeared to trust the client-side JWT claims without proper server-side verification (or used a weak/none signature algorithm).
Gemini said
That’s a classic JWT (JSON Web Token) manipulation vulnerability! Since you've got the technical steps down, let's polish this into a professional CTF (Capture The Flag) Write-up format.

In the security world, clarity and reproducibility are everything. Here is how you can structure that story:

CTF Write-up: TryHeartMe
Challenge Category: Web Exploitation

Difficulty: Easy/Medium

Objective: Purchase the hidden "Valenflag" item from the Valentine's gift shop.

1. Initial Reconnaissance
Upon navigating to http://TARGET_IP:5000, I registered a new account to explore the shop's functionality. The initial dashboard appeared secure, with no obvious injection points or hidden directories visible in the UI.

2. Technical Analysis
I intercepted the traffic using Burp Suite to examine how the application handles session management and user permissions.

I identified a cookie named tryheartme_jwt. After decoding the token, I observed the following JSON structure in the payload:

JSON
{
  "username": "hacker_user",
  "role": "user",
  "credits": 0
}
3. Exploitation (JWT Manipulation)
The application appeared to trust the client-side JWT claims without proper server-side verification (or used a weak/none signature algorithm).

# Steps taken:

I used the 
``` link
https://deventials.com/jwt-editor
```

to modify the token payload.

I elevated my privileges and boosted my balance by changing the values:
``` html
role: "user" → "admin"

credits: 0 → 999
```
I replaced the original cookie in my browser with the newly forged JWT.

# Capturing the Flag
After refreshing the page with the modified token:

My balance updated to 5000 credits (indicating a server-side multiplier.

The hidden "Valenflag" item became visible and purchasable.
