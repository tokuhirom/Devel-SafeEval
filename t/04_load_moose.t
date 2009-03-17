use strict;
use warnings;
use Test::More;
use Devel::SafeEval;

plan skip_all => 'this test requires Moose' unless eval 'package V; use Moose; 1;';
plan tests => 1;

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'package V; use Moose; print "OK"',
    ),
    qr{OK}
);

