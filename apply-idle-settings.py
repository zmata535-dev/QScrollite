#!/usr/bin/env python3
"""Write the Quickshell idle settings to hypridle and restart it."""

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
    "clockTimeout": 9,
    "dimTimeout": 15,
    "displayOffTimeout": 21,
    "lockTimeout": 26,
    "clockTextColor": "#e2e8f0",
    "clockTextSize": 96,
}


def bounded_int(key, minimum, maximum):
    try:
        return max(minimum, min(maximum, int(settings.get(key, defaults[key]))))
    except (TypeError, ValueError):
        return defaults[key]


try:
    settings = {**defaults, **json.loads(settings_path.read_text())}
except (OSError, json.JSONDecodeError):
    settings = defaults.copy()

if len(sys.argv) == 7:
    keys = (
        "clockTimeout",
        "dimTimeout",
        "displayOffTimeout",
        "lockTimeout",
        "clockTextColor",
        "clockTextSize",
    )
    settings.update(zip(keys, sys.argv[1:]))

clock = bounded_int("clockTimeout", 1, 3600)
dim = bounded_int("dimTimeout", 1, 3600)
display_off = bounded_int("displayOffTimeout", 1, 3600)
lock = bounded_int("lockTimeout", 1, 3600)
clock_size = bounded_int("clockTextSize", 32, 160)
clock_color = str(settings.get("clockTextColor", defaults["clockTextColor"]))
if not re.fullmatch(r"#[0-9a-fA-F]{6}", clock_color):
    clock_color = defaults["clockTextColor"]

# Persist sanitized values as well, so the UI and generated daemon config agree.
settings.update(
    clockTimeout=clock,
    dimTimeout=dim,
    displayOffTimeout=display_off,
    lockTimeout=lock,
    clockTextColor=clock_color,
    clockTextSize=clock_size,
)
settings_path.write_text(json.dumps(settings, indent=2) + "\n")

config = f'''general {{
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({{ action = "enable" }})' && brightnessctl -r
}}

listener {{
    timeout = {clock}
    condition_cmd = qs ipc call clock isOpen | grep -qx false
    on-timeout = qs ipc call clock open
    on-resume = qs ipc call clock activity
}}

listener {{
    timeout = {dim}
    on-timeout = brightnessctl -s set 10%
    on-resume = brightnessctl -r
}}

listener {{
    timeout = {display_off}
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({{ action = "disable" }})'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({{ action = "enable" }})'
}}

listener {{
    timeout = {lock}
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
except FileNotFoundError:
    pass
