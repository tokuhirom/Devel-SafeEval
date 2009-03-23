use strict;
use warnings;
use Test::More tests => 23;
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
        code    => 'BEGIN{ unshift @INC, "a";} use Math::BigInt::FastCalc; print "OK"',
    ),
    qr{do not modify \@INC},
    'disallow modify @INC'
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
            package F;
            use overload q{""} => sub { 'Encode' };
            DynaLoader::bootstrap(bless {}, 'F');
...
    ),
    qr{do not ref \$_\[n\]},
    'deny ref module name'
);

#   like(
#       Devel::SafeEval->run(
#           timeout => 1,
#           code    => <<'...'
#               sub Encode::bootstrap { warn 'oops' }
#               DynaLoader::bootstrap('Encode');
#   ...
#       ),
#       qr{bootstrap method is not allowed },
#       'bootstrap'
#   );

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            DynaLoader::bootstrap(bless {}, '0');
...
    ),
    qr{do not ref \$_\[n\]},
    'deny miyagawa'
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

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package F;
                use overload q{""} => sub { Carp::croak "HOGE" };
            }
            unshift @INC, bless({}, 'F');
            DynaLoader::bootstrap('Encode');
...
    ),
    qr{do not ref \$INC\Q[n]},
    'deny ref $INC[0]'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package F;
                use base 'Tie::Scalar';
                sub TIESCALAR { bless {} }
                sub FETCH { Carp::confess() }
            }
            my $x;
            tie $x, 'F';
            DynaLoader::bootstrap($x);
...
    ),
    qr{tied object is not allowed for module name},
    'deny tie $module(kazuho++)'
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            {
                package F;
                use base 'Tie::Array';
                sub TIEARRAY { bless {} }
                sub FETCHSIZE { 3 }
                sub FETCH { warn 'orz'; warn caller(); 1 }
            }
            my @x;
            tie @x, 'F';
            DynaLoader::bootstrap(@x);
...
    ),
    qr{orz},
    'deny tie @_(kazuho++)'
);

unlike(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            sub Encode::define_encoding {
                eval 'package DB;sub f { eval q{$dl_install_xsub->()}; 
                            warn $@ }';
                goto &DB::f;
            }
            XSLoader::load("Encode")
...
    ),
    qr{dl_install_xsub},
    'deny namespace hack @_(kazuho++)'
);

like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...'
            sub Encode::define_encoding {
                die 'orz';
            }
            XSLoader::load("Encode");
            print Encode::encode('utf8', 'hoge');
...
    ),
    qr{hoge},
    'deny namespace hack @_(kazuho++)'
);


like(
    Devel::SafeEval->run(
        timeout => 1,
        code    => <<'...',
            use Encode;
            DynaLoader::dl_unload_file($_) for @DynaLoader::dl_librefs;
            encode('euc-jp', 'abcde');
            print 'ok';
...
    ),
    qr{do not call me},
    'hacked by kazuho++'
);

