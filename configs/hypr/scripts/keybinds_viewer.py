#!/usr/bin/env python3
import os
import re
import sys
import termios
import tty

# -- Config ------------------------------------------------------------------
CANDIDATE_PATHS = [
    "~/.config/hypr/lua/keybindings.lua",
    "~/.config/hypr/keybindings.lua",
    "~/.config/hypr/lua/config/keybindings.lua",
]

EXCLUDED_SECTIONS = [
    "MOUSE BINDINGS",
    "HARDWARE: MEDIA PLAYER CONTROLS"
]

# ANSI Color Codes
CLR_ACCENT = "\033[38;5;45m"  # Teal
CLR_DIM    = "\033[38;5;244m" # Grey
CLR_TEXT   = "\033[38;5;255m" # White
CLR_RESET  = "\033[0m"
CLR_BOLD   = "\033[1m"

KNOWN_VARS = {"TERMINAL": "Terminal", "FILE_MANAGER": "File Manager", "LAUNCHER": "App Launcher"}
MOUSE_NAMES = {"mouse_down": "Scroll Down", "mouse_up": "Scroll Up", "mouse:272": "LMB", "mouse:273": "RMB"}

def resolve_path():
    for p in CANDIDATE_PATHS:
        full = os.path.expanduser(p)
        if os.path.isfile(full): return full
    sys.exit(1)

def find_matching_close(s, open_idx):
    depth, i, n = 0, open_idx, len(s)
    while i < n:
        c = s[i]
        if c in "([{": depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0: return i
        i += 1
    return -1

def split_top_level(s):
    args, current, depth = [], [], 0
    for c in s:
        if c in "([{": depth += 1
        elif c in ")]}": depth -= 1
        elif c == "," and depth == 0:
            args.append("".join(current).strip()); current = []
            continue
        current.append(c)
    if current: args.append("".join(current).strip())
    return args

def extract_string_literal(expr):
    expr = expr.strip()
    for pattern in [r'^\[\[(.*)\]\]$', r'^"(.*)"$', r"^'(.*)'$"]:
        m = re.match(pattern, expr, re.DOTALL)
        if m: return m.group(1)
    return None

def flatten_key_expr(expr, mod_map):
    parts = []
    for tok in expr.split(".."):
        tok = tok.strip()
        lit = extract_string_literal(tok)
        if lit is not None: parts.append(lit)
        elif tok in mod_map: parts.append(mod_map[tok])
        else: parts.append("[N]")
    res = "".join(parts)
    return MOUSE_NAMES.get(res, res)

def humanize_action(expr):
    expr = expr.strip()
    if "exec_cmd" in expr:
        match = re.search(r'exec_cmd\((.*)\)', expr)
        if match:
            target = match.group(1).strip()
            lit = extract_string_literal(target)
            return f"Launch: {lit if lit else KNOWN_VARS.get(target, target)}"
    if "window.close" in expr: return "Close window"
    if "focus" in expr: return "Focus window/workspace"
    if "move" in expr: return "Move window"
    return expr[:50]

def parse_binds(text):
    lines = text.splitlines()
    sections = []
    for i, line in enumerate(lines):
        m = re.match(r'^--\s*[-]{2,}\s*(.+?)\s*[-]{2,}\s*$', line.strip())
        if m: sections.append((i, m.group(1).strip()))

    mod_map = {"mod": "SUPER", "modShift": "SUPER + SHIFT"}
    results = []
    for i, line in enumerate(lines):
        if "hl.bind" in line and not line.strip().startswith("--"):
            start = line.find("hl.bind") + 7
            close = find_matching_close(line[start:], 0)
            if close == -1: continue
            inner = line[start+1:start+close]
            parts = split_top_level(inner)
            if len(parts) < 2: continue
            key = flatten_key_expr(parts[0], mod_map)
            desc = ""
            if i > 0:
                prev = lines[i-1].strip()
                if prev.startswith("--") and "---" not in prev:
                    desc = prev.lstrip("- ").strip()
            if not desc: desc = humanize_action(parts[1])
            current_sec = "General"
            for s_idx, s_title in reversed(sections):
                if s_idx < i:
                    current_sec = s_title
                    break
            if current_sec.upper() in [x.upper() for x in EXCLUDED_SECTIONS]: continue
            results.append({"section": current_sec, "key": key, "desc": desc})
    return results

def render(binds, path):
    grouped = {}
    for b in binds: grouped.setdefault(b['section'], []).append(b)
    print(f"\n {CLR_BOLD}{CLR_ACCENT}OBSIDIAN CORE {CLR_DIM}// {CLR_TEXT}KEYBINDINGS{CLR_RESET}")
    print(f" {CLR_DIM}{'—' * 60}{CLR_RESET}\n")
    for section, s_binds in grouped.items():
        print(f" {CLR_BOLD}{CLR_ACCENT}{section.upper()}{CLR_RESET}")
        for b in s_binds:
            print(f"   {CLR_BOLD}{CLR_TEXT}{b['key']:<22}{CLR_RESET} {CLR_DIM}{b['desc']}{CLR_RESET}")
        print()
    print(f" {CLR_DIM}Press any key to close...{CLR_RESET}", end="", flush=True)

def wait_for_key():
    """Waits for a single keypress so the user can exit instantly."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(sys.stdin.fileno())
        sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def main():
    path = resolve_path()
    with open(path, "r") as f: text = f.read()
    binds = parse_binds(text)
    render(binds, path)
    wait_for_key() # This makes 'q' or any key work

if __name__ == "__main__":
    main()
