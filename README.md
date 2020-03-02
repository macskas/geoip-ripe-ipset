# geoip-ripe-ipset
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
```
