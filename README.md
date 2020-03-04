# geoip-ripe-ipset (iptables geoip replacement)
Its 2020. GeoIP csv is not available. So use RIPE database + ipset instead of geoip iptables module. Just add it to the crontab. IP list is not changing that much, so I recommend 1 update/day.

### dependencies:
 - LWP::UserAgent (ubuntu: libwww-perl)
 - JSON::XS (ubuntu: libjson-xs-perl) (you can replace it with JSON::PP)
 
 
### example
```
server:~/geoip-ripe-ipset# perl ipset_ripe.pl -c DE,LU
Fri Feb 28 19:46:53 2020 INFO  > process_country_ipset(DE)
Fri Feb 28 19:46:53 2020 INFO  > download_country(DE) - https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix;resource=DE loaded from cache.
Fri Feb 28 19:46:53 2020 INFO  > process_country_ipset(DE) - ripe count: 9377, ipset count: 9377, cnt_add (s/f): 0/0, cnt_del(s/f) 0/0
Fri Feb 28 19:46:53 2020 INFO  > process_country_ipset(LU)
Fri Feb 28 19:46:53 2020 INFO  > save_cache_url(https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix;resource=LU) - https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix;resource=LU saved to /tmp/c6a2a91d1142f727bebdde7018a440b4.lwpcache.
Fri Feb 28 19:46:53 2020 INFO  > download_country(LU) - https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix;resource=LU loaded from http.
Fri Feb 28 19:46:53 2020 INFO  > process_country_ipset(LU) - ripe count: 245, ipset count: 0, cnt_add (s/f): 245/245, cnt_del(s/f) 0/0

server:~# ipset list -o save|head -n 10
create ipv4_DE hash:net family inet hashsize 4096 maxelem 65536
add ipv4_DE 85.119.208.0/21
add ipv4_DE 193.29.112.0/20
add ipv4_DE 85.25.174.0/24
add ipv4_DE 188.246.0.0/19
add ipv4_DE 192.54.52.0/24
add ipv4_DE 91.208.48.0/24
add ipv4_DE 92.206.0.0/16
add ipv4_DE 185.1.155.0/24

server:~# iptables-save|grep ipv4_DE
-A TEST -m set --match-set ipv4_DE src -j ACCEPT
server:~# 
```
