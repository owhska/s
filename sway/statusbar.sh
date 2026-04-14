#!/bin/sh

_print() {
	title=$1; shift
	echo -n "$title ${@}${sep}"
}

_need() {
	case $1 in
		*/*) [ -e $1 ] || return 1;;
		*) command -v $1 >/dev/null 2>&1 || return 1;;
	esac
}

_playerctl() {
	_need playerctl || return 0
	msg=$(playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null) || \
	msg=Stopped
	_print MUSIC $msg
}

_net() {
	_need ping || return 0
	ping -c 1 8.8.8.8 >/dev/null 2>&1 && msg=Online || msg=Offline
	_print NET $msg
}

_vol() {
	_need amixer || return 0
	msg=$(amixer get Master | sed -n 's/^.*\[\([0-9]\+\)%.*$/\1/p'| uniq)
	[ "$(amixer get Master | grep Mono: | awk '{print $6}')" = '[off]' ] && msg=X
	_print VOL $msg
}

_bat() {
	[ -d /sys/class/power_supply/BAT0 ] && _bat=0
	[ -d /sys/class/power_supply/BAT1 ] && _bat=1
	[ "$_bat" ] || return 0
	capacity=$(cat /sys/class/power_supply/BAT${_bat}/capacity)
	status=$(cat /sys/class/power_supply/BAT${_bat}/status)
	msg="$([ "$status" = Charging ] && echo +)$capacity"
	_print BAT $msg
}

_ram() {
	used=$(free -m | awk '/Mem:/ { print $3"M" }')
	total=$(free -m | awk '/Mem:/ { print $2"M" }')
	msg="$used/$total"
	_print RAM $msg
}

_temp() {
	_need sensors || return 0
	msg=$(sensors | grep "Package id" | awk '{print $4}' | sed 's/+//')
	_print TEMP $msg
}

_clock() {
	date "+%a %d %b %I:%M:%S"
}

sep=' | '

echo "$(_playerctl)$(_net)$(_temp)$(_ram)$(_bat)$(_vol)$(_clock)"

