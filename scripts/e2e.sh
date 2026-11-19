#!/bin/bash
# End-to-end checks against the installed, running app using real HID-level events.
# Requires: WrapAround running with Accessibility access, and the terminal allowed to
# control the computer (Accessibility) so it can post events.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p build && swiftc -O e2e/driver.swift -o build/driver
D=build/driver; fail=0
read -r W _ < <($D bounds | tr -d '()' | awk -F', ' '{print int($3), int($4)}')
ok(){ echo "PASS  $1"; }; bad(){ echo "FAIL  $1 ($2)"; fail=1; }
xof(){ $D pos | cut -d' ' -f1; }
pref(){ defaults read com.klahadore.wraparound enabled 2>/dev/null || echo 1; }
[ "$(pref)" = 1 ] || { $D hotkey; }

$D warp $((W-10)) 400; $D push 6 4; x=$(xof); [ "$x" -lt 50 ] && ok "right edge wraps to left (x=$x)" || bad "right edge wrap" "x=$x"
$D warp 5 400; $D push -6 4; x=$(xof); [ "$x" -gt $((W-50)) ] && ok "left edge wraps to right (x=$x)" || bad "left edge wrap" "x=$x"
$D warp 800 0; $D push 0 2; y=$($D pos | cut -d' ' -f2); [ "$y" -lt 5 ] && ok "top edge does not wrap" || bad "top edge" "y=$y"
$D warp 800 400; $D push 6 3; x=$(xof); [ "$x" -gt 800 ] && [ "$x" -lt 830 ] && ok "mid-screen motion untouched" || bad "mid-screen" "x=$x"
$D hotkey; [ "$(pref)" = 0 ] && ok "hotkey disables" || bad "hotkey disable" "pref=$(pref)"
$D warp $((W-10)) 400; $D push 6 4; x=$(xof); [ "$x" -ge $((W-2)) ] && ok "no wrap while disabled (x=$x)" || bad "disabled" "x=$x"
$D hotkey; [ "$(pref)" = 1 ] && ok "hotkey re-enables" || bad "hotkey enable" "pref=$(pref)"
$D warp $((W-10)) 400; $D push 6 4; x=$(xof); [ "$x" -lt 50 ] && ok "wraps again after re-enable" || bad "re-enable" "x=$x"
$D warp $((W/2)) 400
exit $fail
