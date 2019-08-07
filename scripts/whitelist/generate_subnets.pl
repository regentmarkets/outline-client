#!/usr/bin/env perl

use strict;
use warnings;

use Path::Tiny;
use Socket;
use XML::LibXML;

sub getHosts {
    my @addresses = gethostbyname(shift);
    return map { inet_ntoa($_) } @addresses[4 .. $#addresses];
}

sub resolveDomains {
    my %lines = map { $_ => 1 } map { chomp; lc; } grep { /^[a-zA-Z0-9]/ } path('domains_list')->lines;

    my %hosts;
    for my $domain (sort keys %lines) {
        my @ip_list = map { s/\.(\d+)$/.0\/24/r } getHosts($domain);
        for my $ip (@ip_list) {
            $hosts{$ip} //= ();
            push @{$hosts{$ip}}, $domain unless grep /^$domain$/, @{$hosts{$ip}};
        }
    }
    return %hosts;
}

sub compareIP {
    my @c = map { join '.', map { sprintf("%03s", $_) } split /\./, $_ } ($a, $b);
    return $c[0] cmp $c[1];
}

sub createXML {
    my ($file_path, $hosts) = @_;

    my $xml  = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $root = $xml->createElement('resources');
    my $sa   = $xml->createElement('string-array');
    $sa->setAttribute('name',         'reserved_bypass_subnets');
    $sa->setAttribute('translatable', 'false');

    for my $ip (sort compareIP keys $hosts->%*) {
        my $domains = $xml->createComment(' ' . (join ', ', @{$hosts->{$ip}}) . ' ');
        $sa->appendChild($domains);

        my $item = $xml->createElement('item');
        $item->appendTextNode($ip);
        $sa->appendChild($item);
    }

    $root->addChild($sa);
    $xml->setDocumentElement($root);

    open(my $fh, '>', $file_path);
    print $fh $xml->toString(1);
    close($fh);
}

my %hosts = resolveDomains();
createXML('bypass_subnets.xml', { %hosts });

1;
