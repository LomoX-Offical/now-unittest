#!/usr/bin/perl

# (C) Nginx, Inc.

# Tests for stream proxy module with datagrams.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;
use Test::Nginx::Stream qw/ dgram /;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/stream/)
	->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

stream {
    proxy_timeout        1s;

    server {
        listen           127.0.0.1:8080 udp;
        proxy_pass       127.0.0.1:8081;

        proxy_responses  0;
    }

    server {
        listen           127.0.0.1:8082 udp;
        proxy_pass       127.0.0.1:8081;

        proxy_responses  2;
    }

    server {
        listen           127.0.0.1:8083 udp;
        proxy_pass       127.0.0.1:8081;
    }
}

EOF


$t->run_daemon(\&udp_daemon, 8081, $t);
$t->try_run('no stream udp')->plan(5);
$t->waitforfile($t->testdir . '/8081');

###############################################################################

my $s = dgram('127.0.0.1:8080');
is($s->io('1', read => 1), '', 'proxy responses 0');

$s = dgram('127.0.0.1:8082');
is($s->io('1'), '1', 'proxy responses 1');
is($s->io('2', read => 2), '12', 'proxy responses 2');
is($s->io('3', read => 3), '12', 'proxy responses 3');

$s = dgram('127.0.0.1:8083');
is($s->io('3', read => 3), '123', 'proxy responses default');

###############################################################################

sub udp_daemon {
	my ($port, $t) = @_;

	my $server = IO::Socket::INET->new(
		Proto => 'udp',
		LocalAddr => "127.0.0.1:$port",
		Reuse => 1,
	)
		or die "Can't create listening socket: $!\n";

	# signal we are ready

	open my $fh, '>', $t->testdir() . '/' . $port;
	close $fh;

	while (1) {
		$server->recv(my $buffer, 65536);
		$server->send($_) for (1 .. $buffer);
	}
}

###############################################################################
