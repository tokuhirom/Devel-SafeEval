use strict;
use warnings;
use Test::More tests => 10;
use Devel::SafeEval;

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'fork()',
    ),
    qr{'fork' trapped by operation mask}
);

is(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'print join ",", keys %ENV',
    ),
    '',
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => '%INC=(); use Encode;',
    ),
    qr{do not load xs}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'print "hoge";',
    ),
    qr{hoge}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'print STDERR "hoge";',
    ),
    qr{hoge}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'DynaLoader::dl_install_xsub("hoge")',
    ),
    qr{do not load xs}
);

like(
    Devel::SafeEval->run(
        timeout => 0.01,
        code    => '1 while 1',
    ),
    qr{timeout},
    'timeout'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'open F, "|-"',
    ),
    qr{'open' trapped by operation mask},
    'open F, "|-"'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'opendir F, "|-"',
    ),
    qr{'opendir' trapped by operation mask},
    'opendir'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'dump()',
    ),
    qr{'dump' trapped by operation mask},
    'dump'
);
