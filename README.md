Общее
===========================================

Все проверено на Raspberry Pi 3 model B+, Raspberry Pi 4, LattePanda и домашнем ПК.
ВАЖНО!!! на Raspberry Pi 4 (в некоторых моделях) стоит ограничение в 7-10 устройств, которые подключаются к wifi. Поэтому если соединения нет, то можно перегрузить плату и она сбросит старые соединения. Или пропатчить ядро, но это совсем сложный путь - пока не освоил.
Проверено на ОС от Raspberry и на Manjaro (ARM и x64).

Зависимости
===========================================

* hostapd
* iptables
* tor
* [create_ap](https://github.com/oblique/create_ap)
* dnsmasq

Принцип работы
===========================================
* tor выполняет роль прокси сервера для всех TCP и UDP (только для DNS) пакетов. Соответственно, если мы хотим поговорить по telegram или используем какой-нибудь хитрый battle.net (который зачем-то использует свои udp порты), то у нас пакеты не будут проходить. Есть способ это ограничение обойти через туннелирование трафика по цепочке весь_трафик-ssh-tor, но там не все так гладко...
* create_ap - это удобный bash скрипт для настройки wifi/hostapd со всеми вытекающими. Больше не поддерживается, но тем не менее там поддерживать нечего. Все отлично работает и не надо парится с dnsmasq.
* iptables - правила настраиваются нами, чтобы все пакеты прероутились на другой IP. Так как нам нежелателен "Маскарад" пакетов - и мы же анонимусы)

Если вы выполняете настройку в графической среде, то настоятельно рекомендую установить firefox. Там очень удобно на лету настраивать проксирование трафика через tor. Да и переключаться между проксями.

Настройка
===========================================
1. tor

установка:
```bash
sudo apt install tor
```
После установки у вас в папке `/etc/tor` появится файл с настройками torrc. Необходимо его будет подшаманить (трогаем только те строчки которые нужны, остальное можно оставить как было. Пример моего конфига скинул, мои настройки в конце файла):
```config
User tor # служба tor запускается от этого пользователя

# Мои настройки
HTTPSProxy IP_PROXY:PORT_PROXY # у меня стоит прокси шлюз в компании, поэтому необходима эта настройка
HTTPSProxyAuthenticator user:password # а это юзер и пароль для шлюза так задается
# Включение всего трафика TCP
TransPort 9040
# Трансляция UDP запросов
AutomapHostsOnResolve 1
DNSPort 9053
# Настройка принимаемых адресов
ReachableAddresses *:80, *:443
ReachableAddresses reject *:*
# Убираю страны через которые не стоит выходить в сеть
ExcludeNodes {ru}
ExcludeExitNodes {us},{au},{ca},{nz},{gb},{fr},{ru}

```
Главное необходимо включить параметры TransPort и DNSPort, а иначе ничего не получится проксировать.
P.S. Можно убрать страны через которые выходим в инет. Я лично убрал страны входящие в соглашение "Five Eyes", так как они следят за узлами своих стран и логируют активность, короче не советую... Ну и убирите те страны, которые географически далеко находятся)

После запускаем службу:
```bash
sudo systemctl start tor.service
# и проверяем:
sudo systemctl status tor.service
```
Если лог такой, то все круто:
```
systemd[1]: Started Anonymizing overlay network for TCP.
Tor[5062]: Bootstrapped 3% (conn_proxy): Connecting to proxy
Tor[5062]: Bootstrapped 4% (conn_done_proxy): Connected to proxy
Tor[5062]: Bootstrapped 10% (conn_done): Connected to a relay
Tor[5062]: Bootstrapped 14% (handshake): Handshaking with a relay
Tor[5062]: Bootstrapped 15% (handshake_done): Handshake with a relay done
Tor[5062]: Bootstrapped 75% (enough_dirinfo): Loaded enough directory info to build circuits
Tor[5062]: Bootstrapped 90% (ap_handshake_done): Handshake finished with a relay to build circuits
Tor[5062]: Bootstrapped 95% (circuit_create): Establishing a Tor circuit
Tor[5062]: Bootstrapped 100% (done): Done
```

Чтобы проверить как все работает, можно включить firefox зайти в настройки (раздел network settings) напротив socks host вставить 127.0.0.1 и порт 9050 (по умолчанию). И проверить свой ip на том же [myip](myip.com)

С tor все! Но не забываем включить автозапуск службы:
```bash
sudo systemctl enable tor.service
```

2. Далее будем настраивать WiFi с помощью create_ap.
Вот так должен выглядеть конфиг в `/etc/create_ap.conf`:
```config
CHANNEL=default
GATEWAY=10.0.0.1 # это адресное пространство для вашей сети
WPA_VERSION=2
ETC_HOSTS=0
DHCP_DNS=gateway
NO_DNS=1 # здесь я игрался с параметром, так как в разных сетях (корпоративной и домашней работало по-разному)
HIDDEN=2 # у анонимусов и wifi скрытый
MAC_FILTER=0
MAC_FILTER_ACCEPT=/etc/hostapd/hostapd.accept
ISOLATE_CLIENTS=0
SHARE_METHOD=none # нам нужно только создать сеть, к инету будем подключать с помощью iptables
IEEE80211N=0
IEEE80211AC=0
HT_CAPAB=[HT40+]
VHT_CAPAB=
DRIVER=nl80211
NO_VIRT=0
COUNTRY=
FREQ_BAND=2.4
NEW_MACADDR=
DAEMONIZE=0
NO_HAVEGED=0
WIFI_IFACE=wlp0s20f3 # имя wifi интерфейса
SSID=name_wifi_network # имя сети
PASSPHRASE=my_password # пароль
USE_PSK=0
```
Имя интерфейса можно узнать так: `ip link` и смотрим как он называется(полное название).
Далее, советую, с помощью команды `create_ap --config /etc/create_ap.conf` посмотреть вывод команды. Могут быть ошибки.
Основная на raspberry это `rfkill: cannot open /dev/rfkill`. Ну или что-то подобное со словом `rfkill`. Выход:
```bash
rfkill unblock wifi
# или более жестко
rfkill unblock all
```
После должно все работать. Поэтому запускаем снова, проверяем, подключаемся с телефона к сети (инета естественно не будет, но нам важен сам процесс подключения). Если все ок, убиваем процесс и запускаем демон:
```bash
sudo systemctl start create_ap.service
# и включаем автозапуск
sudo systemctl enable create_ap.service
```
3. Настройка iptables.
Включаем проброс пакетов (по умолчанию, должен быть включен): `net.ipv4.ip_forward=1` в `/etc/sysctl.conf`.
Включаем службу iptables:
```bash
sudo systemctl start iptables.service
# и включаем автозапуск
sudo systemctl enable iptables.service
```
А вот теперь самое интересное: нам необходимо проксировать трафик в тор не через lo IP (127.0.0.1), а через внешний, который вам присвоен ethernet интерфейсом. А так как мы хотим в разных местах иметь доступ к анонимному инету и не всегда в этих местах есть доступ к dhcp-серверу, то лучше создать bash скрипт, который будет запускаться при включении компьютера, узнавать свой IP и далее настравивать правила iptables. Вот как он будет выглядеть:

```bash
#!/bin/bash
# export IP_ADDR_TUNNEL=$(ip addr | awk '/inet.+enp/ {print $2}' | awk -F/ '{print $1}')

iptables -t nat -X
iptables -t nat -F
iptables -t nat -A PREROUTING -i ap0 -p tcp -j DNAT --to-destination $1:9040
iptables -t nat -A PREROUTING -i ap0 -p udp --dport 53 -j DNAT --to-destination $1:9053
iptables-save -f /etc/iptables/iptables.rules
if [ $( iptables -t nat -L | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" -c) -lt 2 ]; then
    echo "!!!!!!!!HAVE NO IP!!!!!!!"
    iptables -t nat -L | grep "DNAT"
    exit 1
else
    iptables -t nat -L | grep "DNAT"
    echo "set setting iptables is successful"
    exit 0
fi
```
Пройдемся по скрипту:
- На всякий случай оставил в нем команду по определению IP адреса (`export IP_ADDR_TUNNEL ...`)
- Далее чистим все правила, установленные ранее.
- В строчках, где есть слово PREROUTING, настраиваем проброс пакетов на tor. `ap0` это наименование вируального интерфейса wifi (опять же можно проверить с помощью ip link, но по-умолчанию должен быть с таким названием). 
`--to-destination $1:9040`, `$1` - будет браться из настройки юнита systemd, а 9040 - порт, тот который мы настроли в torrc (`TransPort`)
Соответственно для роутинга UDP пакетов используется порт `DNSPort`
- Далее происходит проверка, как запущен данный скрипт (иногда интерфейс ethernet глючит и узнает IP до запуска службы). пока не решил проблему, ввиду того что бывает очень редко.
4. ФИНАЛ
- Настраиваем запуск скрипта из пункта 3, как юнит systemd (iptables-rules-tor.service):

```ini
[Unit]
Description=Writing ip tables rules for wifi-hostspot and tor-proxy
Requires=iptables.service
After=iptables.service syslog.target network.target network-online.target nss-lookup.target
[Service]
# Даем знать systemd, что этот сервис представляет из себя лишь 1 процесс.
Type=oneshot
# Установка переменной окружения
ExecStartPre=/bin/bash -c "/bin/systemctl set-environment IP_ADDR_TUNNEL=$(ip addr | awk '/inet.+enp/ {print $2}' | awk -F/ '{print $1}')"
# Выполнить эту команду при запуске сервиса.
ExecStart=/path/to/iptables.sh ${IP_ADDR_TUNNEL}
# Даем знать systemd, что сервис нужно считать запущенным, даже если основной процесс прекратил свою работу.
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

- Также с помощью делаем оверрайд службы tor, чтобы она также видела внешний IP ethernet (override.conf):

```ini
[Unit]
Wants=network-online.target
After=
After=syslog.target network.target network-online.target nss-lookup.target

[Service]
ExecStartPre=/bin/bash -c "/bin/systemctl set-environment IP_ADDR_TUNNEL=$(ip addr | awk '/inet.+enp/ {print $2}' | awk -F/ '{print $1}')"
ExecStart=
ExecStart=/usr/bin/tor -f /etc/tor/torrc \
    --DNSPort ${IP_ADDR_TUNNEL}:9053 \
    --TransPort ${IP_ADDR_TUNNEL}:9040
```

- И создаем таргет (tor-wifi.target):

```ini
[Unit]
Description=Create wifi hostspot, rulling iptables and start tor
Requires=iptables
Requires=iptables-rules-tor.service
Requires=tor.service
Requires=create_ap.service
After=multi-user.target network.target syslog.target network-online.target nss-lookup.target
[Install]
WantedBy=multi-user.target
```

Делаем:

```bash
sudo systemctl daemon-reload
```

включаем таргет:

```bash
sudo systemctl start tor-wifi.target
sudo systemctl enable tor-wifi.target
```

Перегружаемся и наслаждаемся)
