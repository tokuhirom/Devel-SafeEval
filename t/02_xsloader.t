use strict;
use warnings;
use Test::More tests => 21;
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
    qr{you changed DynaLoader or XSLoader or DB},
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

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            DynaLoader::bootstrap(bless {}, '0');
...
    ),
    qr{ref module name is not allowed},
    'deny miyagawa'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            sub DB::foo { }
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{you changed DynaLoader or XSLoader or DB},
    'deny DB'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package f;
                use base 'Tie::Array';
                sub TIEARRAY { bless {} }
                sub FETCHSIZE { 3 }
                sub FETCH { 1 }
            }
            tie @INC, 'f';
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{do not tie \@INC},
    'deny tie @INC(miyagawa++)'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package f;
                use base 'Tie::Hash';
                sub TIEHASH { bless {} }
                sub FETCH { 1 }
            }
            tie %INC, 'f';
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{do not tie %INC},
    'deny tie %INC(kazuho++)'
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package DB;
                sub f { warn 'k'; eval "\$dl_install_xsub->()"; warn $@ }
            }
            {
                package F;
                use base 'Tie::Scalar';
                sub TIESCALAR { bless {} }
                sub FETCH { goto &DB::f }
            }
            my $x;
            tie $x, 'F';
            DynaLoader::bootstrap($x);
...
    ),
    qr{dl_install_xsub},
    'deny tie $module(kazuho++)'
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package DB;
                sub f { warn 'orz';undef }
            }
            {
                package F;
                use base 'Tie::Hash';
                sub TIEHASH { bless {} }
                sub FIRSTKEY { goto &DB::f }
                sub NEXTKEY { goto &DB::f }
            }
            tie %DB::, 'F';
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{orz},
    'deny tie %DB'
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package DB;
                sub f { warn 'orz';undef }
            }
            {
                package F;
                use base 'Tie::Hash';
                sub TIEHASH { bless {} }
                sub FIRSTKEY { goto &DB::f }
                sub NEXTKEY { goto &DB::f }
            }
            tie %DynaLoader::, 'F';
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{orz},
    'deny tie %DynaLoader'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package F;
                use base 'Tie::Scalar';
                sub TIESCALAR { bless {} }
                sub FETCH { Carp::croak "FETCH" }
            }
            tie $INC[0], 'F';
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{do not tie \$INC},
    'deny tie $INC[0]'
);
