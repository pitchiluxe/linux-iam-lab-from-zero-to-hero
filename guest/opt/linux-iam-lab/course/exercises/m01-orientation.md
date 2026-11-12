---
id: m01-orientation
module: m01
title: Your first login to the jump host
minutes: 15
---
## Ticket
**HELP-1001** - *From: IT Onboarding* - "Welcome to the IAM team! Before you get production access, confirm you can work on the jump host `iamlab01`. Record who you are logged in as and some basic facts about the server in `~/lab/m01/orientation.txt`."

## Objective
Read the Linux prompt, run your first commands, and create a small text file with the `nano` editor.

## Before you start
Open the **Linux terminal** (right-hand panel, or `ssh linux-iam-lab` in Windows Terminal). Everything in this exercise is typed in Linux. No previous exercise is needed.

## Concepts and commands
```linux
whoami
```
Prints the account you are logged in as.
```text
student
```

```linux
hostname
```
Prints the computer's name.
```text
iamlab01
```

```linux
pwd
```
**P**rint **w**orking **d**irectory: where you are right now.
```text
/home/student
```

```linux
id
```
Your user ID (UID), primary group (GID) and every group you belong to. IAM analysts read this output all the time.
```text
uid=1001(student) gid=1001(student) groups=1001(student),4(adm),27(sudo),...
```
Your numbers may differ: read yours, do not copy these. `id -u` prints only the numeric UID.

```linux
echo $SHELL
uname -r
```
`echo` prints text; `$SHELL` is a variable holding your login shell. `uname -r` prints the Linux kernel **r**elease (`uname -a` prints everything).
```text
/bin/bash
6.8.0-87-generic
```

```linux
mkdir -p ~/lab/m01
nano ~/lab/m01/orientation.txt
```
`mkdir -p` makes the folder and any missing parents, and does not complain if it exists. `nano` opens a simple editor: type text, `Ctrl+O` then Enter saves, `Ctrl+X` exits. The bottom two lines of nano list its shortcuts (`^` means Ctrl).

```linux
cat ~/lab/m01/orientation.txt
```
`cat` prints a file.

## Your task
Create `~/lab/m01/orientation.txt` containing these six lines, with the real values from **your** VM:
```text
user=<output of whoami>
host=<output of hostname>
home=<your home folder>
uid=<your numeric uid>
shell=<your login shell>
kernel=<output of uname -r>
```
Create it as `student` (no `sudo`).

## Verify
`cat ~/lab/m01/orientation.txt` and compare each value with the command that produces it. Then press **Check my work** or run `lab check m01-orientation`.

## If it fails
- *no line 'uid=...'*: check the key spelling; keys are lowercase with no spaces before `=`.
- *uid is not right*: you probably copied the example. Run `id -u`.
- *file does not exist*: `ls ~/lab/m01` - the name must be exactly `orientation.txt` (Linux is case-sensitive).
- *should be created by student*: you used `sudo nano`. Delete it with `sudo rm ~/lab/m01/orientation.txt` and create it again without sudo.

## Hints
### Hint 1
Run each command on its own first and read the output: `whoami`, `hostname`, `pwd`, `id`, `echo $SHELL`, `uname -r`.
### Hint 2
`id -u` prints just the number for `uid=`. In nano: `Ctrl+O`, Enter to save; `Ctrl+X` to leave.
### Hint 3
The file looks like `user=student`, `host=iamlab01`, `home=/home/student`, `uid=` plus the number from `id -u`, `shell=/bin/bash`, `kernel=` plus the text from `uname -r`.

## Walkthrough
```linux
whoami
hostname
pwd
id -u
echo $SHELL
uname -r
mkdir -p ~/lab/m01
nano ~/lab/m01/orientation.txt
```
Type the six lines with your values, for example:
```text
user=student
host=iamlab01
home=/home/student
uid=1001
shell=/bin/bash
kernel=6.8.0-87-generic
```
Save with `Ctrl+O`, Enter, exit with `Ctrl+X`, then:
```linux
cat ~/lab/m01/orientation.txt
lab check m01-orientation
```
**Why it matters:** every access investigation starts with "which account, on which machine, with which IDs and groups".
