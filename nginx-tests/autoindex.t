#!/usr/bin/perl

# (C) Maxim Dounin

# Tests for autoindex module.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/http autoindex charset/)->plan(14)
	->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;

        location / {
            autoindex on;
        }
        location /utf8/ {
            autoindex on;
            charset utf-8;
        }
    }
}

EOF

my $d = $t->testdir();

$t->write_file('test-colon:blah', '');
$t->write_file('test-long-' . ('0' x 50), '');
$t->write_file('test-long-' . ('&' x 50), '');
$t->write_file('test-escape-url-%', '');

## ? can't be file name in windows 
#$t->write_file('test-escape-url2-?', '');
$t->write_file('test-escape-html-&', '');

mkdir($d . '/utf8');
$t->write_file('utf8/test-utf8-' . ("\xd1\x84" x 3), '');
$t->write_file('utf8/test-utf8-' . ("\xd1\x84" x 45), '');
$t->write_file('utf8/test-utf8-&-' . "\xd1\x84", '');
$t->write_file('utf8/test-utf8-&-' . ("\xd1\x84" x 45), '');
$t->write_file('utf8/test-utf8-' . ("\xd1\x84" x 3) . '-' . ('&' x 45), '');

mkdir($d . '/test-dir-escape-&');

$t->run();

###############################################################################

my $r = http_get('/');

SKIP: {

skip 'no symlink on win32', 4 if $^O eq 'MSWin32';

like($r, qr!href="test-file"!ms, 'file');
like($r, qr!href="test-file-link"!ms, 'symlink to file');
like($r, qr!href="test-dir/"!ms, 'directory');
like($r, qr!href="test-dir-link/"!ms, 'symlink to directory');

}


unlike($r, qr!href="test-colon:blah"!ms, 'colon not scheme');
like($r, qr!test-long-0{37}\.\.&gt;!ms, 'long name');

like($r, qr!href="test-escape-url-%25"!ms, 'escaped url');
## ? can't be file name in windows 
#like($r, qr!href="test-escape-url2-%3f"!msi, 'escaped ? in url');
like($r, qr!test-escape-html-&amp;!ms, 'escaped html');
#like($r, qr!test-long-(&gt;){37}\.\.&gt;!ms, 'long escaped html');

$r = http_get('/utf8/');

like($r, qr!test-utf8-(\xd1\x84){3}</a>!ms, 'utf8');
like($r, qr!test-utf8-(\xd1\x84){37}\.\.!ms, 'utf8 long');

like($r, qr!test-utf8-&amp;-\xd1\x84</a>!ms, 'utf8 escaped');
like($r, qr!test-utf8-&amp;-(\xd1\x84){35}\.\.!ms,
	'utf8 escaped long');
like($r, qr!test-utf8-(\xd1\x84){3}-(&amp;){33}\.\.!ms, 'utf8 long escaped');

like(http_get('/test-dir-escape-&/'), qr!test-dir-escape-&amp;!ms,
	'escaped title');

###############################################################################
