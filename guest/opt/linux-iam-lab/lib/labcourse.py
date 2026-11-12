"""Course content loader shared by the portal, the agent and the `lab` CLI.

Content lives in Markdown files with a small front-matter block:

    ---
    id: m03-onboard
    module: m03
    title: Onboard a new finance analyst
    ---
    ## Ticket
    ...

Exercise sections are split on '## ' headings; '## Hints' is split further on '### '.
"""
import json
import os
import re

ROOT = os.environ.get("LAB_ROOT", "/opt/linux-iam-lab")
COURSE = os.path.join(ROOT, "course")
EXERCISES = os.path.join(ROOT, "exercises")
ID_RE = re.compile(r"^m\d\d-[a-z0-9][a-z0-9-]{1,40}$")


def _read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().replace("\r\n", "\n")


def parse_front(text):
    meta, body = {}, text
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            for line in text[4:end].splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip()
            body = text[end + 4:].lstrip("\n")
    return meta, body


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def split_sections(body, level=2):
    marker = "#" * level + " "
    out, cur, buf, in_code = [], None, [], False
    for line in body.split("\n"):
        if line.startswith("```"):
            in_code = not in_code
        if not in_code and line.startswith(marker):
            if cur is not None or "".join(buf).strip():
                out.append((cur, "\n".join(buf).strip()))
            cur, buf = line[len(marker):].strip(), []
        else:
            buf.append(line)
    out.append((cur, "\n".join(buf).strip()))
    return [(t, b) for t, b in out if t is not None or b]


def load_exercise(ex_id):
    if not ID_RE.match(ex_id or ""):
        raise ValueError("bad exercise id")
    path = os.path.join(COURSE, "exercises", ex_id + ".md")
    meta, body = parse_front(_read(path))
    sections, hints, walkthrough = [], [], ""
    for title, md in split_sections(body):
        if title is None:
            continue
        key = slug(title)
        if key == "hints":
            hints = [b for t, b in split_sections(md, 3) if t]
        elif key == "walkthrough":
            walkthrough = md
        else:
            sections.append({"title": title, "key": key, "md": md})
    has_check = os.path.isfile(os.path.join(EXERCISES, ex_id + ".sh"))
    return {
        "id": ex_id,
        "module": meta.get("module", ex_id[:3]),
        "title": meta.get("title", ex_id),
        "minutes": int(meta.get("minutes", "15") or 15),
        "prereqs": [p.strip() for p in meta.get("prereqs", "").split(",") if p.strip()],
        "where": meta.get("where", "linux"),
        "sections": sections,
        "hints": hints,
        "walkthrough": walkthrough,
        "hasCheck": has_check,
        "start": meta.get("start", "no").lower() == "yes",
    }


def load_modules():
    mdir = os.path.join(COURSE, "modules")
    mods = []
    for name in sorted(os.listdir(mdir)):
        if not name.endswith(".md"):
            continue
        meta, body = parse_front(_read(os.path.join(mdir, name)))
        mods.append({
            "id": meta.get("id", name[:-3]),
            "number": int(meta.get("number", "0") or 0),
            "title": meta.get("title", name),
            "summary": meta.get("summary", ""),
            "exercises": [e.strip() for e in meta.get("exercises", "").split(",") if e.strip()],
            "lesson": body,
        })
    return mods


def load_course(full=False):
    mods = load_modules()
    out = []
    for m in mods:
        exs = []
        for eid in m["exercises"]:
            try:
                e = load_exercise(eid)
            except (OSError, ValueError):
                continue
            if not full:
                e = {k: e[k] for k in ("id", "module", "title", "minutes", "prereqs", "hasCheck", "start")}
            exs.append(e)
        mm = dict(m)
        mm["exercises"] = exs
        if not full:
            mm.pop("lesson", None)
        out.append(mm)
    return out


def exercise_ids():
    return [e["id"] for m in load_course() for e in m["exercises"]]


def load_reference():
    rdir = os.path.join(COURSE, "reference")
    docs = []
    for name in sorted(os.listdir(rdir)):
        if name.endswith(".md"):
            meta, body = parse_front(_read(os.path.join(rdir, name)))
            docs.append({"id": name[:-3], "title": meta.get("title", name[:-3]), "md": body})
    return docs


if __name__ == "__main__":
    print(json.dumps(load_course(), indent=1))
