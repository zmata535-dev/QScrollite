#!/usr/bin/env python3
"""Apply Quickshell idle settings and synchronize the GTK/Qt icon theme."""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


home = Path.home()
settings_path = home / ".config/quickshell/idle-settings.json"
config_path = home / ".config/hypr/hypridle.conf"
defaults = {
    "compactClockTimeout": 3,
    "compactClockEnabled": True,
    "compactClockOnMediaPlaying": False,
    "clockCardEnabled": True,
    "dimDisplayEnabled": True,
    "clockTimeout": 9,
    "dimTimeout": 15,
    "displayOffTimeout": 21,
    "lockTimeout": 26,
    "clockTextColor": "#e2e8f0",
    "iconTheme": "Suru++",
    "clockTextSize": 96,
    "compactClockTextSize": 36,
    "clockShatterAnimationEnabled": True,
    "clockSlideAnimationEnabled": False,
}


def bounded_int(key, minimum, maximum):
    try:
        return max(minimum, min(maximum, int(settings.get(key, defaults[key]))))
    except (TypeError, ValueError):
        return defaults[key]


def boolean_setting(key):
    value = settings.get(key, defaults[key])
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value).strip().lower() in ("1", "true", "yes", "on")


try:
    settings = {**defaults, **json.loads(settings_path.read_text())}
except (OSError, json.JSONDecodeError):
    settings = defaults.copy()

if len(sys.argv) == 13:
    keys = (
        "compactClockTimeout",
        "clockTimeout",
        "dimTimeout",
        "displayOffTimeout",
        "lockTimeout",
        "compactClockEnabled",
        "clockCardEnabled",
        "dimDisplayEnabled",
        "clockTextColor",
        "clockTextSize",
        "compactClockTextSize",
        "iconTheme",
    )
    settings.update(zip(keys, sys.argv[1:]))
elif len(sys.argv) == 10:
    keys = (
        "compactClockTimeout",
        "clockTimeout",
        "dimTimeout",
        "displayOffTimeout",
        "lockTimeout",
        "clockTextColor",
        "clockTextSize",
        "compactClockTextSize",
        "iconTheme",
    )
    settings.update(zip(keys, sys.argv[1:]))
elif len(sys.argv) == 9:
    keys = (
        "compactClockTimeout",
        "clockTimeout",
        "dimTimeout",
        "displayOffTimeout",
        "lockTimeout",
        "clockTextColor",
        "clockTextSize",
        "compactClockTextSize",
    )
    settings.update(zip(keys, sys.argv[1:]))
elif len(sys.argv) == 8:
    keys = (
        "compactClockTimeout",
        "clockTimeout",
        "dimTimeout",
        "displayOffTimeout",
        "lockTimeout",
        "clockTextColor",
        "clockTextSize",
    )
    settings.update(zip(keys, sys.argv[1:]))
elif len(sys.argv) == 7:
    # Keep accepting the earlier six-value invocation.
    keys = (
        "clockTimeout",
        "dimTimeout",
        "displayOffTimeout",
        "lockTimeout",
        "clockTextColor",
        "clockTextSize",
    )
    settings.update(zip(keys, sys.argv[1:]))

compact_clock = bounded_int("compactClockTimeout", 1, 3600)
clock = bounded_int("clockTimeout", 1, 3600)
dim = bounded_int("dimTimeout", 1, 3600)
display_off = bounded_int("displayOffTimeout", 1, 3600)
lock = bounded_int("lockTimeout", 1, 3600)
clock_size = bounded_int("clockTextSize", 32, 160)
compact_clock_size = bounded_int("compactClockTextSize", 12, 72)
clock_shatter_animation = settings.get("clockShatterAnimationEnabled") is True
clock_slide_animation = settings.get("clockSlideAnimationEnabled") is True
if clock_shatter_animation and clock_slide_animation:
    clock_slide_animation = False
clock_color = str(settings.get("clockTextColor", defaults["clockTextColor"]))
if not re.fullmatch(r"#[0-9a-fA-F]{6}", clock_color):
    clock_color = defaults["clockTextColor"]
compact_clock_enabled = boolean_setting("compactClockEnabled")
compact_clock_on_media_playing = boolean_setting("compactClockOnMediaPlaying")
clock_card_enabled = boolean_setting("clockCardEnabled")
dim_display_enabled = boolean_setting("dimDisplayEnabled")
icon_theme = str(settings.get("iconTheme", defaults["iconTheme"])).strip()
if not re.fullmatch(r"[A-Za-z0-9._ +()-]+", icon_theme):
    icon_theme = defaults["iconTheme"]

# Persist sanitized values as well, so the UI and generated daemon config agree.
settings.update(
    compactClockTimeout=compact_clock,
    clockTimeout=clock,
    dimTimeout=dim,
    displayOffTimeout=display_off,
    lockTimeout=lock,
    compactClockEnabled=compact_clock_enabled,
    compactClockOnMediaPlaying=compact_clock_on_media_playing,
    clockCardEnabled=clock_card_enabled,
    dimDisplayEnabled=dim_display_enabled,
    clockTextColor=clock_color,
    iconTheme=icon_theme,
    clockTextSize=clock_size,
    compactClockTextSize=compact_clock_size,
    clockShatterAnimationEnabled=clock_shatter_animation,
    clockSlideAnimationEnabled=clock_slide_animation,
)
settings_path.write_text(json.dumps(settings, indent=2) + "\n")


def set_ini_value(path, section, key, value):
    try:
        lines = path.read_text().splitlines()
    except OSError:
        lines = []

    section_header = f"[{section}]"
    section_start = next((i for i, line in enumerate(lines) if line.strip() == section_header), -1)
    if section_start < 0:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend((section_header, f"{key}={value}"))
    else:
        section_end = next(
            (i for i in range(section_start + 1, len(lines)) if re.match(r"^\s*\[.+\]\s*$", lines[i])),
            len(lines),
        )
        key_pattern = re.compile(rf"^(\s*){re.escape(key)}\s*=.*$")
        key_index = next(
            (i for i in range(section_start + 1, section_end) if key_pattern.match(lines[i])),
            -1,
        )
        if key_index >= 0:
            indent = key_pattern.match(lines[key_index]).group(1)
            lines[key_index] = f"{indent}{key}={value}"
        else:
            lines.insert(section_end, f"{key}={value}")

    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = path.with_suffix(path.suffix + ".tmp")
    temporary_path.write_text("\n".join(lines) + "\n")
    temporary_path.replace(path)


set_ini_value(home / ".config/gtk-3.0/settings.ini", "Settings", "gtk-icon-theme-name", icon_theme)
set_ini_value(home / ".config/gtk-4.0/settings.ini", "Settings", "gtk-icon-theme-name", icon_theme)
set_ini_value(home / ".config/qt6ct/qt6ct.conf", "Appearance", "icon_theme", icon_theme)

idle_listeners = []
media_playback_condition = " && qs ipc call clock mediaPlaying | grep -qx false" if compact_clock_on_media_playing else ""
if compact_clock_enabled:
    idle_listeners.append(f'''listener {{
    timeout = {compact_clock}
    condition_cmd = qs ipc call idle-settings isOpen | grep -qx false && qs ipc call clock isOpen | grep -qx false
    on-timeout = qs ipc call clock compact
    on-resume = qs ipc call clock activity
}}
''')
if clock_card_enabled:
    idle_listeners.append(f'''listener {{
    timeout = {clock}
    condition_cmd = qs ipc call idle-settings isOpen | grep -qx false && qs ipc call clock isOpen | grep -qx false{media_playback_condition}
    on-timeout = qs ipc call clock open
    on-resume = qs ipc call clock activity
}}
''')
if dim_display_enabled:
    idle_listeners.append(f'''listener {{
    timeout = {dim}
    condition_cmd = qs ipc call clock mediaPlaying | grep -qx false
    on-timeout = brightnessctl -s set 10%
    on-resume = brightnessctl -r
}}
''')

config = f'''general {{
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({{ action = "enable" }})' && brightnessctl -r
}}

{''.join(idle_listeners)}
listener {{
    timeout = {display_off}
    condition_cmd = qs ipc call clock mediaPlaying | grep -qx false
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({{ action = "disable" }})'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({{ action = "enable" }})'
}}

listener {{
    timeout = {lock}
    condition_cmd = qs ipc call clock mediaPlaying | grep -qx false
    on-timeout = hyprlock
}}
'''

config_path.parent.mkdir(parents=True, exist_ok=True)
temporary_path = config_path.with_suffix(".conf.tmp")
temporary_path.write_text(config)
temporary_path.replace(config_path)

try:
    subprocess.run(["pkill", "-x", "hypridle"], check=False)
    for _ in range(30):
        still_running = subprocess.run(
            ["pgrep", "-x", "hypridle"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if still_running.returncode != 0:
            break
        time.sleep(0.1)
    subprocess.Popen(
        ["hypridle"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    if not dim_display_enabled:
        subprocess.run(["brightnessctl", "-r"], check=False)
except FileNotFoundError:
    pass
