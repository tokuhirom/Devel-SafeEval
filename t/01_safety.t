use strict;
use warnings;
use Test::More tests => 8;
use Devel::SafeEval;
use English;

like(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => 'fork()',
    ),
    qr{'fork' trapped by operation mask}
);

is(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => 'print join ",", keys %ENV',
    ),
    '',
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => '%INC=(); use Encode;',
    ),
    qr{do not load xs}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => 'print "hoge";',
    ),
    qr{hoge}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => 'print STDERR "hoge";',
    ),
    qr{hoge}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => 'DynaLoader::dl_install_xsub("hoge")',
    ),
    qr{do not load xs}
);

like(
    Devel::SafeEval->run(
        timeout => 0.01,
        uid     => $UID,
        code    => '1 while 1',
    ),
    qr{timeout},
    'timeout'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        uid     => $UID,
        code    => 'open F, "|-"',
    ),
    qr{'open' trapped by operation mask},
    'open F, "|-"'
);

