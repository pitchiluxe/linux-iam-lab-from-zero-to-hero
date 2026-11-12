# YourGithub: ready-to-publish GitHub content (Linux IAM Lab)

Everything you need to publish the Linux IAM lab on GitHub. Each numbered folder is a **complete repository**: copy the folder, fill in every `[BRACKET]` (search for `[`), rewrite the first paragraph in your own words, then push.

## Files

| File / folder | Goes where |
| --- | --- |
| `00-profile-README.md` | `README.md` of a repo named exactly like your username (`pitchiluxe/pitchiluxe`). Shows on your profile page. Covers both labs. |
| `01-linux-contractor-access-lifecycle/` | Repo `linux-contractor-access-lifecycle`: the capstone, its sudo rule, runbook, notes and **real test report** |
| `02-linux-access-report/` | Repo `linux-access-report`: the read-only `access-report.sh` with its README and a real sample CSV |
| `03-linux-ssh-sudo-hardening/` | Repo `linux-ssh-sudo-hardening`: the sudo rule and sshd hardening files, a note on every line |
| `04-repo-descriptions-and-topics.md` | The "About" box (description + topics) of each repo, and the pin order |

## What is already real, and what you add

| Already in the folders | You add |
| --- | --- |
| Test report from a real capstone run (`01/evidence/CAP-9001-test-report.txt`) | Your **own** run's report: `lab capstone evidence`, then copy it from `~/capstone/evidence/` |
| The access-report script, tested read-only in the lab VM, plus a real CSV | Your CAP-9002 root cause (the lab breaks the login differently for everyone) |
| Config files validated with `visudo -cf` and `sshd -t` | Your lessons in "What I learned", your screenshots |

## Publish one repo

```bash
cp -r 01-linux-contractor-access-lifecycle ~/linux-contractor-access-lifecycle
cd ~/linux-contractor-access-lifecycle
git init -b main && git add -A && git commit -m "Contractor access lifecycle on Linux"
gh repo create linux-contractor-access-lifecycle --public --source . --push
```

## Order

1. `linux-access-report` first (smallest, gets a link live).
2. `linux-ssh-sudo-hardening`.
3. `linux-contractor-access-lifecycle` once you have finished the capstone and have your own report.
4. Profile README last, once every link works. Pin the three repos.

## Before every push

- [ ] Every `[BRACKET]` replaced or deleted (`grep -rn '\[' .`)
- [ ] No passwords, tokens or private keys: `git grep -nIiE 'password|token|secret|BEGIN .*PRIVATE'`
- [ ] No private key files: `git ls-files | grep -E 'id_(rsa|ed25519)$|\.pem$|\.key$'`
- [ ] No real hostnames, IPs or company names: only `iamlab01`, `127.0.0.1`, documentation ranges (`192.0.2.x`) and fictional *Northwind Labs*
- [ ] Screenshots cropped: no Windows username, no browser tabs, no token in an address bar
- [ ] Your Gmail address not in any file or commit: `git log --format='%ae' | sort -u` (use GitHub's `noreply` address)
- [ ] Each artifact labelled **real**, **written by me** or **template**
