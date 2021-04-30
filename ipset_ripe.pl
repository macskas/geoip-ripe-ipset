#!/usr/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use JSON::XS;
use Digest::MD5 qw(md5_hex);
use Getopt::Std;


my $url_ripe = "https://stat.ripe.net/data/country-resource-list/data.json?v4_format=prefix&resource=";
my $dir_cache = "/tmp";
my $cache_time = 3600;
my $http_api_timeout = 20;
my $ipset_prefix = "ipv4_";
my $ipset_maxelem = 0;
my @countries = ( );
my $p_ipset = "/sbin/ipset";

sub do_error()
{
    my $msg = shift || "-";
    printf("%s ERROR > %s\n", scalar localtime, $msg);
    exit(1);
}

sub do_warn()
{
    my $msg = shift || "-";
    printf("%s WARN  > %s\n", scalar localtime, $msg);
}

sub do_info()
{
    my $msg = shift || "-";
    printf("%s INFO  > %s\n", scalar localtime, $msg);
}

$SIG{ALRM} = sub {
    &do_error("ALRM received. Command timeout reached.");
};

sub decode_json_eval()
{
    my $input = shift || "";
    my $out = 0;
    eval {
        $out = decode_json($input);
        1;
    } or do {
        my $e = $@;
        chomp($e);
        &do_warn("JSON error: $e");
        $out = 0;
    };

    return $out;
}

sub save_cache_url()
{
    my $url = shift || &do_error("Missing url from save_reponse");
    my $content = shift || 0;
    my $cachefile = $dir_cache . "/". md5_hex($url) . ".lwpcache";
    if (!$content || length($content) < 10) {
	return 0;
    }
    local *F;
    open(F, ">$cachefile") or return 0;
    print F $content;
    close(F);
    &do_info("save_cache_url($url) - $url saved to $cachefile.");
    return 1;
}

sub load_cache_url()
{
    my $url = shift || &do_error("Missing url from save_reponse");
    my $cachefile = $dir_cache . "/". md5_hex($url) . ".lwpcache";
    if (!-f $cachefile) {
	return 0;
    }
    my @fstat = stat($cachefile);
    if (scalar @fstat == 0) {
	return 0;
    }
    my $mtime = $fstat[9];
    my $now = time();
    my $diff = $now-$mtime;
    if ($diff > $cache_time) {
	return 0;
    }
    if ($now < $mtime) {
	&do_warn("Cachefile is in the future.");
	return 0;
    }
    local *F;
    open(F, $cachefile) or &do_error("Unable to open $cachefile ($!)");
    read(F, my $content, -s $cachefile);
    close(F);
    my $json_decode = &decode_json_eval($content);
    if (!$json_decode) {
        &do_error("Unable to retrieve database from $url. Invalid JSON.");
    }
    if (!defined($json_decode->{'status'})) {
        &do_error("Unable to retrieve database from $url. Missing status key from json.");
    }
    return $json_decode;
}


sub download_country()
{
    my $country = shift || &do_error("Missing paramter from download_country.");
    my $url = $url_ripe . "$country";
    my $r1 = &load_cache_url($url);
    if ($r1) {
	&do_info("download_country($country) - $url loaded from cache.");
	return $r1;
    }
    my $ua = LWP::UserAgent->new;
    $ua->timeout($http_api_timeout);
    my $req = $ua->get($url);
    if ($req->is_success) {
	my $json_decode = &decode_json_eval($req->content);
	if (!$json_decode) {
	    &do_error("Unable to retrieve database from $url. Invalid JSON.");
	}
	if (!defined($json_decode->{'status'})) {
	    &do_error("Unable to retrieve database from $url. Missing status key from json.");
	}
	&save_cache_url($url, $req->content);
	&do_info("download_country($country) - $url loaded from http.");
	return $json_decode;
    } else {
	&do_error("Unable to retrieve database from $url. Non-200 response");
    }
}

sub process_country_ipset()
{
    my $country = shift || &do_error("Missing param country from &process_country_ipset");
    my $ipset_name = "$ipset_prefix$country";
    &do_info("process_country_ipset($country)");
    my $json_data = &download_country($country);
    if (!defined($json_data->{'data'}->{'resources'}->{'ipv4'})) {
	&do_warn("Country: $country is not processed. Missing key data/resources/ipv4");
	return 0;
    }
    my @ipv4_list = @{$json_data->{'data'}->{'resources'}->{'ipv4'}};
    my $list_num = scalar @ipv4_list;
    if ($list_num < 30) {
	&do_warn("Country: $country is not processed. too few entries received ($list_num < 30)");
    }

    my $ipv4_map_ipset = &ipset_list($country);
    my $ipv4_map_ripe = {};
    my @list_add = ();
    my @list_del = ();
    
    foreach my $ip (@ipv4_list) {
	$ipv4_map_ripe->{"$ip"} = 1;
	if (!defined($ipv4_map_ipset->{"$ip"})) {
	    push(@list_add, $ip);
	}
    }
    
    foreach my $ip (keys %{$ipv4_map_ipset}) {
	if (!defined($ipv4_map_ripe->{"$ip"})) {
	    push(@list_del, $ip);
	}
    }

    my $cnt_add = scalar @list_add;
    my $cnt_del = scalar @list_del;
    my $cnt_ripe = scalar keys %{$ipv4_map_ripe};
    my $cnt_ipset = scalar keys %{$ipv4_map_ipset};

    # larger batch - we dont have feedback
    if ($cnt_add + $cnt_del > 1000) {
	my @restoreContent = ();
	foreach my $entry (@list_add) {
    	    push(@restoreContent, "add $ipset_name $entry");
	}
	foreach my $entry (@list_del) {
    	    push(@restoreContent, "del $ipset_name $entry");
	}
	&ipset_restore(join("\n", @restoreContent) ."\n");

	&do_info(
	    sprintf("process_country_ipset(%s) - ripe count: %d, ipset count: %d, cnt_add: %d, cnt_del: %d",
		$country,
		$cnt_ripe,
		$cnt_ipset,
		$cnt_add,
		$cnt_del
	    )
	);

	return 1;
    }
    
    my $added = 0;
    foreach my $ip (@list_add) {
	$added += &ipset_entry_manage("add", $ipset_name, "$ip");
    }

    my $deleted = 0;
    foreach my $ip (@list_del) {
	$deleted += &ipset_entry_manage("del", $ipset_name, "$ip");
    }

    
    &do_info(
	sprintf("process_country_ipset(%s) - ripe count: %d, ipset count: %d, cnt_add (s/f): %d/%d, cnt_del(s/f) %d/%d",
	    $country,
	    $cnt_ripe,
	    $cnt_ipset,
	    $cnt_add,
	    $added,
	    $cnt_del,
	    $deleted
	)
    );
}

sub ipset_restore()
{
    my $restoreContent = shift;
    local *P;
    open(P, "| $p_ipset restore") or &do_error("Unable to run ipset restore (ipset_restore)");
    print P $restoreContent;
    close(P);
    my $rc = $? >> 8;
    if ($rc != 0) {
	&do_warn("Unable to run $p_ipset restore. return code=$rc");
	return 0;
    }
    return 1;
}


sub ipset_entry_manage()
{
    my $action = shift;
    my $ipset_name = shift;
    my $ip = shift;
    local *P;
    open(P, "$p_ipset $action $ipset_name $ip |") or &do_error("Unable to run ipset $action (ipset_entry_manage)");
    close(P);
    my $rc = $? >> 8;
    if ($rc != 0) {
	&do_warn("Unable to run $p_ipset $action $ipset_name $ip. return code=$rc");
	return 0;
    }
    return 1;

}

sub ipset_create()
{
    my $ipset_name = shift;
    local *P;
    open(P, "$p_ipset create $ipset_name hash:net |") or &do_error("Unable to run ipset command (create)");
    close(P);
    my $rc = $? >> 8;
    if ($rc != 0) {
	&do_error("Unable to run ipset create command. return code=$rc");
    }
    return 1;
}

sub ipset_list()
{
    my $country = shift;
    my $ipset_name = "$ipset_prefix$country";
    my $ipset = {};
    local *P;
    open(P, "$p_ipset list $ipset_name -o plain 2>/dev/null |") or &do_error("Unable to run ipset command (list)");
    while (<P>) {
	if ($_ =~ /^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(?:\/[0-9]{1,2})?)$/) {
	    $ipset->{$1} = 1;
	}
    }
    close(P);
    my $rc = $? >> 8;
    if ($rc == 0) {
	return $ipset;
    } elsif ($rc == 1) {
	&ipset_create($ipset_name);
	return $ipset;
    } else {
	&do_error("Unknown ipset error");
    }
    return $ipset;
}

sub ipset_destroy()
{
    my $country = shift;
    my $ipset_name = "$ipset_prefix$country";
    local *P;
    open(P, "$p_ipset destroy $ipset_name |") or &do_error("Unable to run ipset command (destroy)");
    close(P);
    my $rc = $? >> 8;
    if ($rc == 0) {
	&do_info("Ipset deleted: $ipset_name");
	return 1;
    } else {
	&do_warn("ipset delete error: rc=$rc");
    }
    return 0;    
}

sub do_help()
{
    print("$0 -c <countryCodes> [-e <maxelem>] [-t <http cache time>] [-p <ipset prefix>] [-D]\n");
    print("     -c <countryCodes>  - Example: DE,LU,FR\n");
    print("     -e <int>           - Default: 65536 (kernel default), min=1 000, max=1 000 000\n");
    print("     -t <seconds>       - Default: 3600, You should cache response from ripe. min=600, max=30 000 000\n");
    print("     -p <ipset prefix>  - Default: ipv4_\n");
    print("     -D                 - Destroy all ipset with the specified prefix\n");
    
    print "\n";
    exit(1);
}

sub main()
{
    my %opts = ();
    getopts("c:e:t:p:D", \%opts);
    my $cinput = "";
    
    if (defined($opts{'c'})) {
	$cinput = $opts{'c'};
    } else {
	&do_help();
    }
    
    if (defined($opts{'e'})) {
	my $tmpval = $opts{'e'};
	if ($tmpval =~ /^[0-9]+$/) {
	    $tmpval = int($tmpval);
	    if ($tmpval > 1000 && $tmpval < 1000000) {
		$ipset_maxelem = $tmpval;
	    } else {
		&do_warn("Invalid ipset_maxelem ($tmpval)");
	    }
	}
    }

    if (defined($opts{'t'})) {
	my $tmpval = $opts{'t'};
	if ($tmpval =~ /^[0-9]+$/) {
	    $tmpval = int($tmpval);
	    if ($tmpval >= 600 && $tmpval <= 30000000) {
		$cache_time = $tmpval;
	    } else {
		&do_warn("Invalid cache_time $tmpval")
	    }
	}
    }

    if (defined($opts{'p'})) {
	my $tmpval = $opts{'p'};
	if ($tmpval =~ /^[a-z0-9_]+$/) {
	    $ipset_prefix = $tmpval;
	} else {
	    &do_warn("Invalid ipset_prefix $tmpval");
	}
    }
    
    
    my @clist = split(/,/, $cinput);
    foreach my $cin (@clist) {
	if ($cin !~ /^[A-Z]{2,3}$/) {
	    &do_warn("Invalid country format: $cin");
	} else {
	    push(@countries, $cin);
	}
    }
    if (scalar @countries == 0) {
	&do_error("Empty country list.");
    }

    if (defined($opts{'D'})) {
	foreach my $country (@countries) {
	    $country = uc($country);
	    &ipset_destroy($country);
	}
	return 0;
    }

    foreach my $country (@countries) {
	$country = uc($country);
	&process_country_ipset($country);
    }
}

&main();
