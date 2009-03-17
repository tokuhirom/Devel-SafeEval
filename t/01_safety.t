use strict;
use warnings;
use Test::More tests => 16;
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
        code    => 'print join ",", sort keys %ENV',
    ),
    'PATH,PERL5LIB',
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
    qr{do not call me},
    'dl_install_xsub is dangerous'
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

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use Devel::Peek',
    ),
    qr{no xs},
    'Devel::Peek is dangerous...(that can detect address)'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'DynaLoader::boot_DynaLoader()',
    ),
    qr{you should not call},
    'DynaLoader::boot_DynaLoader'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'DynaLoader::boot_DynaLoader()',
    ),
    qr{you should not call},
    'DynaLoader::boot_DynaLoader'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use Encode; print encode("iso-2022-jp", "DAN")',
    ),
    qr{DAN},
    'DynaLoader::boot_DynaLoader'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => '#line',
    ),
    qr{#line is not allowed},
    'deny #line'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => "warn '#line'; warn 'OK!'",
    ),
    qr{OK!},
    'allow "#line" in string'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => "1;\n#line 3 'hoge'",
    ),
    qr{#line is not allowed},
    'deny #line in the next line'
);
