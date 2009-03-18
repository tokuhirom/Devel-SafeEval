use strict;
use warnings;
use Test::More tests => 12;
use Devel::SafeEval;

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use Opcode; print "OK"',
    ),
    qr{OK}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use Encode; print "OK"',
    ),
    qr{OK}
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => q{
            use strict;
            sub strict::import { DynaLoader::dl_install_xsub };
            use Encode;
            print "OK";
        },
    ),
    qr{Usage: DynaLoader::dl_install_xsub}
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => q{#line 1 "HOGE"
            use strict;
            sub strict::import { DynaLoader::dl_install_xsub };
            use Encode;
            print "OK";
        },
    ),
    qr{Usage: DynaLoader::dl_install_xsub}
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use less do { DynaLoader::dl_install_xsub }',
    ),
    qr{Usage: DynaLoader::dl_install_xsub}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use threads; print "OK"',
    ),
    qr{OK}
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'use Math::BigInt::FastCalc; print "OK"',
    ),
    qr{OK},
    'allow Math::BigInt::FastCalc'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'BEGIN{ unshift @INC, sub { };} use Math::BigInt::FastCalc; print "OK"',
    ),
    qr{do not modify \@INC},
    'disallow modify @INC'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => 'BEGIN{ *XSLoader::load = sub { }} use Math::BigInt::FastCalc; print "OK"',
    ),
    qr{you changed DynaLoader or XSLoader},
    'disallow modify XSLoader/DynaLoader'
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
        {
            local *Encode::dl_load_flags = sub {
                Carp::cluck();
                my $key = Devel::SafeEval::Defender->can('key')->();
                print "key='$key'";
            };
            DynaLoader::bootstrap('Encode');
        }
...
    ),
    qr{key='[a-zA-Z0-9]+'},
    'yappo attack'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            sub DB::DB { }
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{i hate debugger},
    'deny debugger'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            package F;
            use overload q{""} => sub { 'Encode' };
            DynaLoader::bootstrap(bless {}, 'F');
...
    ),
    qr{ref module name is not allowed},
    'deny ref module name'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            sub Encode::bootstrap { warn 'oops' }
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{bootstrap method is not allowed },
    'bootstrap'
);
