#!/usr/bin/env python3
"""Dump AT-SPI names of the isolated Z Privacy window. Read-only.

Does not click, type, or call get_extents: Flutter's ATK component times out
on extents and the app logs impl_GetExtents assertions.

The GTK application name is `com.monopeak.zprivacy`. get_id() is an int.
"""
from __future__ import annotations

import sys

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402


def _as_text(value: object) -> str:
    if value is None:
        return ""
    return str(value)


def is_zprivacy(name: str, app_id: object) -> bool:
    blob = f"{name} {_as_text(app_id)}".lower()
    return any(s in blob for s in ("zprivacy", "z privacy", "z-privacy", "monopeak.zprivacy"))


def walk(acc, depth=0, lines=None, limit=400):
    if lines is None:
        lines = []
    if len(lines) >= limit:
        return lines
    try:
        name = acc.get_name() or ""
        role = acc.get_role_name() or ""
        lines.append(f"{'  '*depth}{role}: {name}")
    except Exception as e:  # noqa: BLE001
        lines.append(f"{'  '*depth}ERR {e}")
        return lines
    try:
        n = acc.get_child_count()
    except Exception:
        return lines
    for i in range(n):
        try:
            child = acc.get_child_at_index(i)
        except Exception:
            continue
        if child is not None:
            walk(child, depth + 1, lines, limit)
    return lines


def main() -> int:
    desktop = Atspi.get_desktop(0)
    n = desktop.get_child_count()
    found = False
    for i in range(n):
        app = desktop.get_child_at_index(i)
        if app is None:
            continue
        name = app.get_name() or ""
        try:
            app_id = app.get_id()
        except Exception:
            app_id = ""
        print(f"APP {name!r} id={app_id!r}")
        if not is_zprivacy(name, app_id):
            continue
        found = True
        for line in walk(app):
            print(line)
    if not found:
        print("no Z Privacy accessible app found", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
