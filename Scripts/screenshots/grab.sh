#!/bin/zsh
# usage: grab.sh <popover|key> <output.png>  — saves/restores clipboard text
S="${0:A:h}"
pbpaste > "$S/.clip-backup.txt" 2>/dev/null
note=com.chanchalgeek.LinkShelf.debug.capturePopover
[[ "$1" == key ]] && note=com.chanchalgeek.LinkShelf.debug.captureKeyWindow
notifyutil -p "$note"; sleep 1
osascript -e "set f to open for access POSIX file \"$2\" with write permission" -e "set eof f to 0" -e "write (the clipboard as «class PNGf») to f" -e "close access f"
pbcopy < "$S/.clip-backup.txt"; rm -f "$S/.clip-backup.txt"
sips -g pixelWidth -g pixelHeight "$2" | tail -2
