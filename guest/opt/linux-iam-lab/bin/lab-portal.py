#!/usr/bin/python3
"""Linux IAM Lab course portal (runs as the unprivileged 'labportal' user).

Python standard library only, so it works offline. Serves the single-page portal, the course
and reference content, proxies exercise checks/resets to the root agent over its Unix socket,
and relays tutor questions to the VM-local Ollama (127.0.0.1:11434). It never runs shell
commands and never sends secrets to the model: shared terminal text is redacted first.
"""
import hmac
import http.client
import http.server
import json
import os
import re
import socket
import socketserver
import sys
import urllib.parse

sys.path.insert(0, "/opt/linux-iam-lab/lib")
import labcourse  # noqa: E402

ETC = "/etc/linux-iam-lab"
STATIC = "/opt/linux-iam-lab/portal/static"
SOCK = "/run/linux-iam-lab/agent.sock"
LISTEN_PORT = int(os.environ.get("LAB_PORTAL_PORT", "8080"))
OLLAMA = ("127.0.0.1", 11434)


def read(path, default=""):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return default


SETTINGS = dict(l.split("=", 1) for l in read(f"{ETC}/settings.env").splitlines() if "=" in l)
TOKEN = read(f"{ETC}/portal.token")
TERM_TOKEN = read(f"{ETC}/terminal.token")
MODEL = SETTINGS.get("OLLAMA_MODEL", "qwen2.5:1.5b")
COOKIE = "labsession"

# ------------------------------------------------------------------------------ redaction
REDACTIONS = [
    (re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----", re.S), "[REDACTED PRIVATE KEY]"),
    (re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*", re.S), "[REDACTED PRIVATE KEY]"),
    (re.compile(r"\$(?:1|2[aby]|5|6|y|gy|7)\$[^\s:]{8,}"), "[REDACTED PASSWORD HASH]"),
    (re.compile(r"\{SSHA\}[A-Za-z0-9+/=]+"), "[REDACTED PASSWORD HASH]"),
    (re.compile(r"(?i)\b(password|passwd|pwd|secret|token|api[_-]?key)(\s*=\s*)(\S+)"), r"\1\2[REDACTED]"),
    (re.compile(r"(?im)^(\s*(?:new |current |retype new )?password\s*:\s*)(\S+)\s*$"), r"\1[REDACTED]"),
    (re.compile(r"(?i)(echo\s+['\"]?[a-z0-9_.-]+:)([^'\"\s|]+)(['\"]?\s*\|\s*(?:sudo\s+)?chpasswd)"), r"\1[REDACTED]\3"),
    (re.compile(r"(?i)(userPassword::?\s*)\S+"), r"\1[REDACTED]"),
    (re.compile(r"(?i)(-w\s+|--password[= ])\S+"), r"\1[REDACTED]"),
]


def redact(text):
    count = 0
    for secret in (TOKEN, TERM_TOKEN):
        if secret and secret in text:
            count += text.count(secret)
            text = text.replace(secret, "[REDACTED LAB TOKEN]")
    for rx, rep in REDACTIONS:
        text, n = rx.subn(rep, text)
        count += n
    return text, count


# ------------------------------------------------------------------------------ agent client
def agent(req, timeout=400):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect(SOCK)
        s.sendall((json.dumps(req) + "\n").encode())
        data = b""
        while not data.endswith(b"\n"):
            chunk = s.recv(65536)
            if not chunk:
                break
            data += chunk
        return json.loads(data.decode() or "{}")
    except OSError as exc:
        return {"ok": False, "error": f"lab agent unavailable: {exc}"}
    finally:
        s.close()


# ------------------------------------------------------------------------------ tutor
SYSTEM_PROMPT = """You are the instructor inside the Linux IAM Lab, a beginner course that turns learners into Linux-capable Identity and Access Management (IAM) analysts.
Rules you always follow:
1. You CANNOT run commands and you cannot see the learner's computer. Never claim you ran or checked anything. You only explain and guide.
2. Never ask for, accept or repeat passwords, private keys, tokens or password hashes. If the learner shares one, tell them to remove it and treat it as exposed.
3. Teach instead of handing over answers. Guide with a question or the next small step. Do not give the complete solution for the current exercise unless the learner says they have tried and asks for the walkthrough; then point them to the Walkthrough section of the exercise.
4. When asked about a command, explain BEFORE it is run: what it does, each option/flag, what output to expect, and any risk (deleting data, changing access, locking someone out). Recommend validation (visudo -c, sshd -t) before applying security changes.
5. Be clear about WHERE commands are typed: Windows PowerShell on the host (prompt PS C:\\...>) versus Linux bash in the lab VM (prompt student@iamlab01:~$).
6. Keep answers short: at most about 150 words, plain language, commands in fenced code blocks.
7. Everything in this lab is fictional (company Northwind Labs, users like aokafor, btran, dpatel). Stay within the lab.
8. If you are not sure, say so and suggest the man page (man <command>) or the course reference library."""

MODES = {
    "explain": "The learner wants a command explained BEFORE running it. Explain what it does, each flag, expected output and risks. Do not run it.",
    "error": "The learner shared terminal output that may contain an error. Interpret the message, name the most likely cause, and suggest ONE diagnostic command to confirm it. Do not give the full fix yet.",
    "quiz": "Quiz the learner. Ask ONE short question about the current exercise or module concepts and wait. If their message answers a previous quiz question, say whether it is right and why, then ask the next question.",
    "nudge": "Give the smallest helpful nudge: a guiding question or which command family to look at. No full commands for the solution.",
    "chat": "Answer the learner's question following the rules.",
}


def exercise_context(ex_id):
    if not ex_id:
        return "The learner is browsing the course (no exercise selected)."
    try:
        e = labcourse.load_exercise(ex_id)
    except (OSError, ValueError):
        return "Unknown exercise."
    parts = [f"Current exercise: {e['title']} (id {e['id']})."]
    for s in e["sections"]:
        if s["key"] in ("ticket", "objective", "your-task", "before-you-start", "concepts-and-commands", "if-it-fails"):
            parts.append(f"## {s['title']}\n{s['md'][:900]}")
    if e["hints"]:
        parts.append("Hints you may reveal ONE AT A TIME, weakest first:\n" + "\n".join(f"- {h[:300]}" for h in e["hints"]))
    text = "\n\n".join(parts)
    return text[:3500]


def ollama_request(method, path, body=None, timeout=10):
    conn = http.client.HTTPConnection(*OLLAMA, timeout=timeout)
    conn.request(method, path, body=json.dumps(body) if body is not None else None,
                 headers={"Content-Type": "application/json"})
    return conn, conn.getresponse()


def tutor_status():
    try:
        conn, r = ollama_request("GET", "/api/tags", timeout=3)
        tags = json.loads(r.read() or b"{}")
        conn.close()
        names = [m.get("name") for m in tags.get("models", [])]
        return {"online": True, "model": MODEL, "modelReady": MODEL in names or f"{MODEL}:latest" in names}
    except (OSError, ValueError):
        return {"online": False, "model": MODEL, "modelReady": False}


# ------------------------------------------------------------------------------ HTTP
class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "LinuxIAMLabPortal/1.0"

    def log_message(self, fmt, *args):  # keep tokens out of logs
        msg = fmt % args
        sys.stderr.write(re.sub(r"token=[A-Za-z0-9]+", "token=[REDACTED]", msg) + "\n")

    # --- helpers
    def send_json(self, obj, code=200, headers=None):
        data = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def host_ok(self):
        host = re.sub(r":\d+$", "", (self.headers.get("Host") or "").strip())
        return host in ("127.0.0.1", "localhost", "[::1]")

    def authed(self):
        raw = self.headers.get("Cookie", "")
        for part in raw.split(";"):
            k, _, v = part.strip().partition("=")
            if k == COOKIE and TOKEN and hmac.compare_digest(v, TOKEN):
                return True
        return False

    def body_json(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 200_000:
            raise ValueError("request too large")
        return json.loads(self.rfile.read(n) or b"{}")

    def static(self, rel):
        rel = rel.lstrip("/") or "index.html"
        path = os.path.realpath(os.path.join(STATIC, rel))
        if not path.startswith(STATIC + os.sep) or not os.path.isfile(path):
            return self.send_json({"error": "not found"}, 404)
        ctype = {".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml",
                 ".png": "image/png", ".ico": "image/x-icon", ".json": "application/json"}.get(os.path.splitext(path)[1], "application/octet-stream")
        with open(path, "rb") as fh:
            data = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype + ("; charset=utf-8" if ctype.startswith("text") else ""))
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(data)

    # --- routing
    def do_GET(self):
        if not self.host_ok():
            return self.send_json({"error": "bad host"}, 403)
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        if u.path == "/api/health":
            return self.send_json({"ok": True})
        if "token" in q:
            if TOKEN and hmac.compare_digest(q["token"][0], TOKEN):
                self.send_response(302)
                self.send_header("Set-Cookie", f"{COOKIE}={TOKEN}; Path=/; HttpOnly; SameSite=Strict")
                self.send_header("Location", "/")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            return self.send_json({"error": "invalid token"}, 403)
        if not self.authed():
            if u.path.startswith("/api/"):
                return self.send_json({"error": "open the lab with the Start Linux IAM Lab shortcut"}, 401)
            return self.static("locked.html")
        if u.path == "/api/course":
            return self.send_json({"modules": labcourse.load_course(full=True)})
        if u.path == "/api/reference":
            return self.send_json({"docs": labcourse.load_reference()})
        if u.path == "/api/progress":
            return self.send_json(agent({"op": "progress"}))
        if u.path == "/api/progress/export":
            data = json.dumps(agent({"op": "progress"}).get("progress", {}), indent=1).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Disposition", 'attachment; filename="linux-iam-lab-progress.json"')
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if u.path == "/api/status":
            st = agent({"op": "status"}, timeout=20)
            return self.send_json({"services": st.get("services", {}), "tutor": tutor_status(),
                                   "settings": {"sshPort": SETTINGS.get("HOST_SSH_PORT"), "fingerprint": SETTINGS.get("HOST_KEY_FINGERPRINT")}})
        if u.path == "/api/terminal":
            # Opened inside the VM (Host 127.0.0.1:8080) -> ttyd on 7681; from Windows -> the forwarded port.
            host_port = (self.headers.get("Host") or "").rsplit(":", 1)[-1]
            port = "7681" if host_port == str(LISTEN_PORT) else SETTINGS.get("HOST_TERMINAL_PORT", "7681")
            return self.send_json({"url": f"http://127.0.0.1:{port}/t/{TERM_TOKEN}/"})
        return self.static(u.path)

    def do_POST(self):
        if not self.host_ok():
            return self.send_json({"error": "bad host"}, 403)
        if not self.authed() or self.headers.get("X-Lab") != "1":
            return self.send_json({"error": "not authorised"}, 401)
        parts = [p for p in urllib.parse.urlparse(self.path).path.split("/") if p]
        try:
            if parts[:2] == ["api", "check"] and len(parts) == 3:
                return self.send_json(agent({"op": "check", "id": parts[2]}))
            if parts[:2] == ["api", "reset"] and len(parts) == 3:
                return self.send_json(agent({"op": "reset", "id": parts[2]}))
            if parts[:2] == ["api", "hint"] and len(parts) == 4:
                return self.send_json(agent({"op": "hint", "id": parts[2], "level": int(parts[3])}))
            if parts[:2] == ["api", "lesson"] and len(parts) == 3:
                return self.send_json(agent({"op": "lesson", "id": parts[2]}))
            if parts[:2] == ["api", "rescue"] and len(parts) == 3:
                return self.send_json(agent({"op": "rescue", "what": parts[2]}))
            if parts[:2] == ["api", "capstone"] and len(parts) == 3:
                return self.send_json(agent({"op": "capstone", "action": parts[2]}))
            if parts == ["api", "tutor"]:
                return self.tutor(self.body_json())
        except (ValueError, IndexError) as exc:
            return self.send_json({"error": str(exc)}, 400)
        return self.send_json({"error": "not found"}, 404)

    def tutor(self, req):
        mode = req.get("mode", "chat")
        if mode not in MODES:
            mode = "chat"
        message, n1 = redact(str(req.get("message", ""))[:2000])
        shared, n2 = redact(str(req.get("shared", ""))[-4000:])
        history = []
        for h in (req.get("history") or [])[-6:]:
            if h.get("role") in ("user", "assistant"):
                history.append({"role": h["role"], "content": redact(str(h.get("content", ""))[:1500])[0]})
        ctx = exercise_context(str(req.get("exerciseId") or ""))
        user = f"[Mode: {mode}] {MODES[mode]}\n\n"
        if shared.strip():
            user += f"Terminal output the learner chose to share (redacted):\n```\n{shared}\n```\n\n"
        user += f"Learner: {message or '(no message)'}"
        msgs = [{"role": "system", "content": SYSTEM_PROMPT + "\n\nCourse context:\n" + ctx}] + history + [{"role": "user", "content": user}]
        body = {"model": MODEL, "messages": msgs, "stream": True,
                "options": {"temperature": 0.3, "num_ctx": 4096, "num_predict": 260}}
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        def chunk(obj):
            data = (json.dumps(obj) + "\n").encode()
            self.wfile.write(f"{len(data):x}\r\n".encode() + data + b"\r\n")
            self.wfile.flush()

        chunk({"redacted": n1 + n2})
        try:
            conn, r = ollama_request("POST", "/api/chat", body, timeout=300)
            if r.status != 200:
                chunk({"error": f"tutor model error {r.status}: {r.read()[:200].decode(errors='replace')}"})
            else:
                for line in r:
                    if not line.strip():
                        continue
                    ev = json.loads(line)
                    piece = ev.get("message", {}).get("content", "")
                    if piece:
                        chunk({"t": piece})
                    if ev.get("done"):
                        chunk({"done": True, "evalCount": ev.get("eval_count"), "seconds": round((ev.get("total_duration") or 0) / 1e9, 1)})
                        break
            conn.close()
        except (OSError, ValueError) as exc:
            chunk({"error": f"The tutor is offline ({exc.__class__.__name__}). Lessons, hints and checks still work."})
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    Server(("0.0.0.0", LISTEN_PORT), Handler).serve_forever()
