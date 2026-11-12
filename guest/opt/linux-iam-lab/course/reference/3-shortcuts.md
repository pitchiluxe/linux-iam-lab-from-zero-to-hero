---
title: Shortcuts
---
Keyboard shortcuts for Windows Terminal (on the Windows host), the Bash shell (in Linux), the portal's web terminal, and the editors used in this course.

### Windows Terminal: tabs and panes (Windows host)
| Keys | Action |
|---|---|
| `Ctrl+Shift+T` | new tab (default profile) |
| `Ctrl+Shift+1..9` | new tab with profile 1..9 |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | next / previous tab |
| `Ctrl+Shift+W` | close pane/tab |
| `Alt+Shift+D` | split pane (duplicate) |
| `Alt+Shift+-` / `Alt+Shift++` | split horizontally / vertically |
| `Alt+Arrow` | move between panes |
| `Ctrl+Shift+F` | find in the scrollback |
| `Ctrl+Shift+P` | command palette |
| `Ctrl+,` | settings |

### Windows Terminal: copy and paste (Windows host)
| Keys | Action |
|---|---|
| select with mouse, then `Ctrl+C` or `Enter` | copy (when text is selected) |
| `Ctrl+V` or `Ctrl+Shift+V` | paste |
| right-click | paste (or context menu, depending on settings) |
| `Ctrl+=` / `Ctrl+-` / `Ctrl+0` | zoom in / out / reset |
Note: `Ctrl+C` with **no** selection sends "interrupt" to the program, just like in Linux.

### Connecting from Windows Terminal to the lab
```powershell
ssh linux-iam-lab
```
Works after install because the installer added a `Host linux-iam-lab` entry to `C:\Users\you\.ssh\config` with the lab key and the pinned host key. Equivalent long form: `ssh -p 2422 -i $HOME\.ssh\linux-iam-lab_student_ed25519 student@127.0.0.1`. Type `exit` or press `Ctrl+D` to return to Windows.

### Bash: moving on the command line (Linux)
| Keys | Action |
|---|---|
| `Ctrl+A` / `Ctrl+E` | start / end of line |
| `Alt+B` / `Alt+F` | back / forward one word |
| `Ctrl+Left` / `Ctrl+Right` | back / forward one word (most terminals) |
| `Ctrl+XX` | toggle between start of line and cursor |

### Bash: editing (Linux)
| Keys | Action |
|---|---|
| `Ctrl+U` | cut from cursor to start of line |
| `Ctrl+K` | cut from cursor to end of line |
| `Ctrl+W` | cut previous word |
| `Alt+D` | cut next word |
| `Ctrl+Y` | paste what you cut |
| `Ctrl+_` | undo |
| `Alt+.` | insert last argument of the previous command (repeat to go further back) |
| `Tab` / `Tab Tab` | complete / list completions |

### Bash: history (Linux)
| Keys / command | Action |
|---|---|
| `Up` / `Down` | previous / next command |
| `Ctrl+R` | reverse search; `Ctrl+R` again for older match; `Enter` run; `Esc` or `Right` to edit; `Ctrl+G` cancel |
| `history` / `history 20` | list history / last 20 |
| `!!` | repeat last command (e.g. `sudo !!`) - read it before pressing Enter |
| `!42` | run history entry 42 |
| `!$` | last argument of previous command |
| `HISTTIMEFORMAT` | set in this lab, so `history` shows timestamps |

### Bash: control (Linux)
| Keys | Action |
|---|---|
| `Ctrl+C` | interrupt (stop) the running command |
| `Ctrl+D` | end of input; on an empty prompt: log out |
| `Ctrl+Z` | suspend the running command (`fg` resumes, `bg` continues in background, `jobs` lists) |
| `Ctrl+L` | clear the screen |
| `Ctrl+S` / `Ctrl+Q` | freeze / unfreeze output (if the screen "hangs", try `Ctrl+Q`) |

### Portal web terminal (browser)
| Keys | Action |
|---|---|
| select text | copies automatically in many browsers; otherwise right-click > Copy |
| `Ctrl+Shift+V` / right-click | paste |
| `Ctrl+Shift+C` | copy (where supported) |
Browser shortcuts such as `Ctrl+W` may close the browser tab - use the pop-out terminal or `ssh linux-iam-lab` if you rely on Bash's `Ctrl+W`.

### nano editor (Linux)
| Keys | Action |
|---|---|
| `Ctrl+O`, `Enter` | save |
| `Ctrl+X` | exit (asks to save if changed) |
| `Ctrl+W` | search |
| `Ctrl+K` / `Ctrl+U` | cut line / paste |
| `Alt+U` | undo |
| `Ctrl+_` | go to line number |
| `Alt+#` | toggle line numbers |

### less and man pages (Linux)
| Keys | Action |
|---|---|
| `Space` / `b` | page down / up |
| `/pattern` `Enter` | search forward; `n` next, `N` previous |
| `g` / `G` | top / bottom |
| `q` | quit |

### vim survival (Linux)
`Esc` then `:q!` `Enter` quits without saving. `Esc` then `:wq` `Enter` saves and quits. `i` starts typing (insert mode).
