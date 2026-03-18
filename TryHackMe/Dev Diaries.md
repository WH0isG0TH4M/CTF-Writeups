# Room: Dev Diaries
### Difficulty: Easy
### Objectives: Hunt through online development traces to uncover what was left behind.
``` plain text
We have just launched a website developed by a freelance developer. The source code was not shared with us, and the developer has since disappeared without handing it over.
Despite this, traces of the development process and earlier versions of the website may still exist online.
You are only given the website's primary domain as a starting point: marvenly.com
```
The first thing I did was search for the domain name, but I couldn’t find anything useful. So, I used crt.sh to perform subdomain enumeration and found a subdomain:
### uat-testing.marvenly.com

### Question 1: What is the subdomain where the development version of the website is hosted?
### Answer: uat-testing.marvenly.com

While browsing the website, I noticed the developer’s name in the footer. I used this information to find his GitHub account.

### Question 2: What is the GitHub username of the developer?
### Answer: notvibecoder23

Next, I cloned the repository to analyze its commit history and retrieve more information such as the developer’s email.
``` bash
git clone https://github.com/notvibecoder23/marvenly_site.git
cd marvenly_site
git log
```
Result:
``` bash
Author: notvibecoder23 <freelancedevbycoder23@gmail.com>
```
### Question 3: What is the developer's email address?
### Answer: freelancedevbycoder23@gmail.com

The developer has multiple commits. By reviewing the commit history, I identified the reason why the project was abandoned. The relevant commit can be found here:
https://github.com/notvibecoder23/marvenly_site/commit/88baf1db29d7530a51c7bc13ae9f3c1b9a1eae25

### Question 4: What reason did the developer mention in the commit history for removing the source code?
### Answer: The project was marked as abandoned due to a payment dispute

After reviewing all commits, I found the flag in one of them:
https://github.com/notvibecoder23/marvenly_site/commit/33c59e5feedcbcbfee7a1f6d3a435225698f616f

### Question 5: What is the value of the hidden flag?
### Answer: THM{REDACTED}
