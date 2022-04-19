#!/bin/bash
# Скрипт, необходим для запуска службы systemd,
# которая будет назначать правила при загрузке системы.
# Нам необходимо проксировать трафик в Tor не через lo IP (127.0.0.1),
# а через внешний (ИНАЧЕ РАБОТАТЬ НЕ БУДЕТ!!!), который вам присвоен
# ethernet интерфейсом. А так как мы хотим иметь доступ к анонимному инету 
# всегда и не всегда в этих местах есть доступ к dhcp-серверу,
# то нам необходимо узнавать свой IP и далее настравивать правила iptables.


# Команда для поиска IP адреса присвоенного DHCP-сервером.
# Не используется, оставил для справки
# export IP_ADDR_TUNNEL=$(ip addr | awk '/inet.+enp/ {print $2}' | awk -F/ '{print $1}')

# Стираем предыдущие правила
iptables -t nat -X
iptables -t nat -F
# Назначаем новые в зависисти от назначенного IP адреса "$1".
iptables -t nat -A PREROUTING -i ap0 -p tcp -j DNAT --to-destination $1:9040
iptables -t nat -A PREROUTING -i ap0 -p udp --dport 53 -j DNAT --to-destination $1:9053
# Сохраняем правила, эту строку можно закомментировать.
iptables-save -f /etc/iptables/iptables.rules
# Вывод результатов запуска, чтобы можно было посмотреть результат, с помощью
# команды systemd status.
if [ $( iptables -t nat -L | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" -c) -lt 2 ]; then
    echo "!!!!!!!!HAVE NO IP!!!!!!!"
    iptables -t nat -L | grep "DNAT"
    exit 1
else
    iptables -t nat -L | grep "DNAT"
    echo "set setting iptables is successful"
    exit 0
fi
