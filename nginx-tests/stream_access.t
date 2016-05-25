#!/usr/bin/perl

# (C) Andrey Zelenkov
# (C) Nginx, Inc.

# Tests for stream access module.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;
use Test::Nginx::Stream qw/ stream /;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/stream stream_access ipv6/);

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

stream {
    server {
        listen       127.0.0.1:8082;
        proxy_pass   [::1]:8080;
    }

    server {
        listen       127.0.0.1:8085;
        proxy_pass   [::1]:8081;
    }

    server {
        listen       127.0.0.1:8088;
        proxy_pass   [::1]:8082;
    }

    server {
        listen       127.0.0.1:8091;
        proxy_pass   [::1]:8083;
    }


    server {
        listen       127.0.0.1:8094;
        proxy_pass   [::1]:8084;
    }

    server {
        listen       127.0.0.1:8097;
        proxy_pass   [::1]:8085;
    }

    server {
        listen       127.0.0.1:8081;
        listen       [::1]:8080;
        proxy_pass   127.0.0.1:8080;
        allow        all;
    }

    server {
        listen       127.0.0.1:8084;
        listen       [::1]:8081;
        proxy_pass   127.0.0.1:8080;
        deny         all;
    }

    server {
        listen       127.0.0.1:8090;
        listen       [::1]:8083;
        proxy_pass   127.0.0.1:8080;
        deny         127.0.0.1;
    }

    server {
        listen       127.0.0.1:8093;
        listen       [::1]:8084;
        proxy_pass   127.0.0.1:8080;
        deny         ::1;
    }

}

EOF

$t->try_run('no inet6 support')->plan(12);
$t->run_daemon(\&stream_daemon);
$t->waitforsocket('127.0.0.1:8080');

###############################################################################

my $str = 'SEE-THIS';

# allow all

is(stream('127.0.0.1:8081')->io($str), $str, 'inet allow all');
is(stream('127.0.0.1:8082')->io($str), $str, 'inet6 allow all');

# deny all

is(stream('127.0.0.1:8084')->io($str), '', 'inet deny all');
is(stream('127.0.0.1:8085')->io($str), '', 'inet6 deny all');

# deny inet

is(stream('127.0.0.1:8090')->io($str), '', 'inet deny inet');
is(stream('127.0.0.1:8091')->io($str), $str, 'inet6 deny inet');

# deny inet6

is(stream('127.0.0.1:8093')->io($str), $str, 'inet deny inet6');
is(stream('127.0.0.1:8094')->io($str), '', 'inet6 deny inet6');

###############################################################################

sub stream_daemon {
	my $server = IO::Socket::INET->new(
		Proto => 'tcp',
		LocalAddr => '127.0.0.1:8080',
		Listen => 5,
		Reuse => 1
	)
		or die "Can't create listening socket: $!\n";

	local $SIG{PIPE} = 'IGNORE';

	while (my $client = $server->accept()) {
		$client->autoflush(1);

		log2c("(new connection $client)");

		$client->sysread(my $buffer, 65536) or next;

		log2i("$client $buffer");

		log2o("$client $buffer");

		$client->syswrite($buffer);

		close $client;
	}
}

sub log2i { Test::Nginx::log_core('|| <<', @_); }
sub log2o { Test::Nginx::log_core('|| >>', @_); }
sub log2c { Test::Nginx::log_core('||', @_); }

###############################################################################
