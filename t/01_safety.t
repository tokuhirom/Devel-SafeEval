use strict;
use warnings;
use Test::More tests => 5;
use Devel::SafeEval;
use English;

like(
    Devel::SafeEval->run(
        root    => '/',
        timeout => 1,
        uid     => $UID,
        code    => 'fork()',
    ),
    qr{Opcode denied: fork}
);

is(
    Devel::SafeEval->run(
        root    => '/',
        timeout => 1,
        uid     => $UID,
        code    => 'print join ",", keys %ENV',
    ),
    '',
);

like(
    Devel::SafeEval->run(
        root    => '/',
        timeout => 1,
        uid     => $UID,
        code    => '%INC=(); use Encode;',
    ),
    qr{do not load xs}
);


like(
    Devel::SafeEval->run(
        root    => '/',
        timeout => 1,
        uid     => $UID,
        code    => 'print "hoge";',
    ),
    qr{hoge}
);

like(
    Devel::SafeEval->run(
        root    => '/',
        timeout => 1,
        uid     => $UID,
        code    => 'print STDERR "hoge";',
    ),
    qr{hoge}
);

