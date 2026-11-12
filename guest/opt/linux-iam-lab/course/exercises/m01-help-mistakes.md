---
id: m01-help-mistakes
module: m01
title: Use the manual and fix awkward file names
minutes: 20
prereqs: m01-files
---
## Ticket
**HELP-1003** - *From: Team lead* - "Someone left badly named files in `~/lab/m01/messy`. Rename `quarterly report.txt` to `quarterly-report.txt` and delete the file called `-old-notes.txt`. While you are at it, use the built-in manual to answer the questions in the task - I want you to be able to look things up yourself."

## Objective
Use `man`, `--help`, Tab completion, history and `Ctrl+R`; handle file names containing spaces or starting with `-`; recover when a command misbehaves.

## Before you start
Linux terminal. The folder `~/lab/m01/messy` was prepared for you.

## Concepts and commands
```linux
man ls
```
Opens the manual for `ls`. Move with the arrow keys or Space, search with `/human` then Enter, jump to the next match with `n`, quit with `q`.

```linux
ls --help | less
```
Most commands print a short usage summary with `--help`. Piping it into `less` lets you scroll (pipes are module 2; for now, read it as "show it page by page").

```linux
man 5 passwd
```
Manual pages are grouped in **sections**. Section 1 is commands (`man 1 passwd` documents the `passwd` command); section 5 is file formats (`man 5 passwd` documents the `/etc/passwd` file). `man man` lists the sections.

```linux
cd ~/lab/m01/messy
ls -l
```
```text
-rw-r--r-- 1 student student 25 Nov 11 10:00 -old-notes.txt
-rw-r--r-- 1 student student 31 Nov 11 10:00 quarterly report.txt
```

```linux
mv "quarterly report.txt" quarterly-report.txt
```
The shell splits words on spaces, so a name with a space must be **quoted** (or the space escaped: `quarterly\ report.txt`). Tip: type `quar` and press Tab - completion escapes it for you.

```linux
rm -- -old-notes.txt
```
`rm -old-notes.txt` fails because `rm` thinks `-o...` are options (`rm: invalid option -- 'o'`). `--` tells a command "everything after this is a file name". `rm ./-old-notes.txt` also works.

```linux
history | tail -5
```
Shows your last commands with numbers. Press `Ctrl+R` and type `quar` to find the `mv` command again without retyping it.

## Your task
1. In `~/lab/m01/messy`: rename `quarterly report.txt` to `quarterly-report.txt` and delete `-old-notes.txt`. Do not touch `keep-me.txt`.
2. Create `~/lab/m01/help.txt` with these lines, filling each answer from `man` or `--help`:
```text
human=<the ls option that prints sizes like 1K 234M 2G>
hidden=<the ls option that also shows names starting with .>
interactive=<the rm option that asks before every removal>
passwd_section=<the man section number that documents the /etc/passwd FILE format>
cancel=<the key combination that cancels a running command, written like ctrl+x>
```

## Verify
`ls -l ~/lab/m01/messy` should show `keep-me.txt` and `quarterly-report.txt` only. `cat ~/lab/m01/help.txt`. Then **Check my work**.

## If it fails
- *`mv: target 'report.txt' is not a directory`*: the space was not quoted, so `mv` saw three arguments.
- *`rm: invalid option -- 'o'`*: add `--` before the name.
- *An answer is wrong*: search the man page with `/` (for example `/human` in `man ls`).
- Stuck inside `man` or `less`? Press `q`. Stuck with no prompt? `Ctrl+C`.

## Hints
### Hint 1
For the renames: quotes protect spaces, and `--` protects names that start with a dash. For the questions: `man ls` then type `/human` and Enter.
### Hint 2
`ls -h` alone does nothing visible; it changes sizes in long format (`ls -lh`). Look in `man rm` for "prompt before every removal". `man man` lists the sections: 5 is file formats.
### Hint 3
The answers are `-h`, `-a`, `-i`, `5` and `ctrl+c`.

## Walkthrough
```linux
cd ~/lab/m01/messy
ls -l
mv "quarterly report.txt" quarterly-report.txt
rm -- -old-notes.txt
ls -l
```
```text
-rw-r--r-- 1 student student 18 Nov 11 10:00 keep-me.txt
-rw-r--r-- 1 student student 31 Nov 11 10:00 quarterly-report.txt
```
```linux
man ls        # type /human  -> -h, --human-readable ; q to quit
man rm        # -i  prompt before every removal
man man       # section 5 = File formats and conventions
nano ~/lab/m01/help.txt
```
```text
human=-h
hidden=-a
interactive=-i
passwd_section=5
cancel=ctrl+c
```
```linux
lab check m01-help-mistakes
```
Now try `Ctrl+R` and type `mv "q` - the shell finds your earlier command. Press `Ctrl+C` to leave the search without running it.
