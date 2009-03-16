use strict;
use warnings;
use Test::More tests => 2;
use Devel::SafeEval;

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use Encode; print "OK"',
    ),
    qr{OK}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use threads; print "OK"',
    ),
    qr{OK}
);

