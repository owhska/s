#!/bin/bash

query=$(rofi -dmenu -p "Pesquisar")
[ -z "$query" ] && exit

encoded=$(printf '%s' "$query" | sed 's/ /+/g')
url="https://www.google.com/search?q=$encoded"

# pega navegador padrão
browser=$(xdg-settings get default-web-browser)

# tenta extrair nome (remove .desktop)
browser=${browser%.desktop}

# tenta focar no sway (app_id)
swaymsg "[app_id=\"$browser\"] focus"

# abre no navegador padrão
xdg-open "$url"
