---
id: m01-files
module: m01
title: Organise the ticket workspace
minutes: 20
prereqs: m01-orientation
---
## Ticket
**HELP-1002** - *From: Team lead* - "Your ticket inbox at `~/lab/m01/inbox` is a mess. Sort the tickets into `open` and `closed` folders under `~/lab/m01/tickets`, delete the editor junk file, keep a copy of the onboarding checklist from the handbook in `~/lab/m01`, and remove the empty inbox when you are done."

## Objective
Navigate with `cd`, `ls` and Tab completion; read files with `cat`/`less`; create, copy, move and delete files and folders safely.

## Before you start
Linux terminal. The lab created `~/lab/m01/inbox` with three tickets and one junk file, and the read-only handbook in `/opt/lab-data/handbook`.

## Concepts and commands
```linux
cd ~/lab/m01/inbox
ls -la
```
`cd` changes folder (use Tab after typing `~/lab/m` to complete). `ls -l` shows details; `-a` also shows hidden files (names starting with `.`).
```text
total 24
drwxr-xr-x 2 student student 4096 Nov 11 10:00 .
drwxr-xr-x 3 student student 4096 Nov 11 10:00 ..
-rw-r--r-- 1 student student   12 Nov 11 10:00 draft.txt~
-rw-r--r-- 1 student student  140 Nov 11 10:00 ticket-1001.txt
-rw-r--r-- 1 student student  138 Nov 11 10:00 ticket-1002.txt
-rw-r--r-- 1 student student  151 Nov 11 10:00 ticket-1003.txt
```

```linux
cat ticket-1001.txt
less ticket-1002.txt
```
`cat` prints the whole file; `less` pages through long files (Space = next page, `q` = quit). Each ticket has a `Status:` line.

```linux
mkdir -p ~/lab/m01/tickets/open ~/lab/m01/tickets/closed
```
Creates both folders (and `tickets` itself) in one command.

```linux
mv ticket-1001.txt ~/lab/m01/tickets/closed/
```
`mv SOURCE DEST/` moves a file into a folder. The trailing `/` makes it clear `DEST` is a folder. `mv old new` in the same folder renames.

```linux
cp /opt/lab-data/handbook/onboarding-checklist.txt ~/lab/m01/
```
`cp` copies. The original stays where it is. Use `cp -r` for folders.

```linux
rm -i 'draft.txt~'
rmdir ~/lab/m01/inbox
```
`rm -i` asks before deleting (`y` to confirm). `rmdir` only removes an **empty** folder, which makes it a safe way to tidy up: if it refuses with `Directory not empty`, something is still inside.

```linux
ls -R ~/lab/m01/tickets
```
`-R` lists recursively, folder by folder.

## Your task
1. Read each ticket in `~/lab/m01/inbox` and move it to `~/lab/m01/tickets/open/` or `~/lab/m01/tickets/closed/` according to its `Status:` line. Keep the file names.
2. Delete the junk file `draft.txt~`.
3. Copy `/opt/lab-data/handbook/onboarding-checklist.txt` into `~/lab/m01/` (leave the original in place).
4. Remove the now-empty `~/lab/m01/inbox` folder.

## Verify
```linux
ls -R ~/lab/m01
```
You should see the two ticket folders, the checklist and no inbox. Then **Check my work**.

## If it fails
- *ticket in the wrong folder*: `cat` it again and read `Status:`. Move it with `mv`.
- *`rmdir: failed to remove ... Directory not empty`*: run `ls -la ~/lab/m01/inbox`; something (perhaps the junk file) is still inside.
- *`cannot stat`*: the path is misspelled. Use Tab completion.
- Made a mess? Press **Retry exercise** to get a fresh inbox.

## Hints
### Hint 1
Start with `cd ~/lab/m01/inbox`, then `ls -la`, then `cat` each ticket and look for the word `Status`.
### Hint 2
Create both destination folders at once with `mkdir -p` and move tickets with `mv ticket-XXXX.txt ~/lab/m01/tickets/open/` (or `closed/`). The junk file name contains `~`, so quote it.
### Hint 3
Two tickets are OPEN and one is CLOSED. After moving all three and deleting `'draft.txt~'`, `cd ~/lab/m01` and run `rmdir inbox`.

## Walkthrough
```linux
cd ~/lab/m01/inbox
ls -la
cat ticket-1001.txt ticket-1002.txt ticket-1003.txt
```
```text
Ticket: HELP-1001 ... Status: CLOSED
Ticket: HELP-1002 ... Status: OPEN
Ticket: HELP-1003 ... Status: OPEN
```
```linux
mkdir -p ~/lab/m01/tickets/open ~/lab/m01/tickets/closed
mv ticket-1001.txt ~/lab/m01/tickets/closed/
mv ticket-1002.txt ticket-1003.txt ~/lab/m01/tickets/open/
rm -i 'draft.txt~'
cp /opt/lab-data/handbook/onboarding-checklist.txt ~/lab/m01/
cd ~/lab/m01
rmdir inbox
ls -R ~/lab/m01
lab check m01-files
```
`mv` accepts several sources when the last argument is a folder. `cd ~/lab/m01` first, because you cannot remove the folder you are standing in.
