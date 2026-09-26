#!/bin/sh
set -e

ip6tables -N LAMP_GUARD 2>/dev/null || true
ip6tables -F LAMP_GUARD

while ip6tables -D INPUT -p tcp --dport 1337 -j LAMP_GUARD 2>/dev/null; do
    :
done

ip6tables -A LAMP_GUARD \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

ip6tables -A LAMP_GUARD \
  -p tcp --syn --dport 1337 \
  -m connlimit \
  --connlimit-above 3 \
  --connlimit-mask 128 \
  -j REJECT --reject-with tcp-reset

ip6tables -A LAMP_GUARD \
  -p tcp --syn --dport 1337 \
  -m connlimit \
  --connlimit-above 8 \
  --connlimit-mask 0 \
  -j REJECT --reject-with tcp-reset

ip6tables -A LAMP_GUARD -j RETURN

ip6tables -I INPUT 1 \
  -p tcp --dport 1337 \
  -j LAMP_GUARD
