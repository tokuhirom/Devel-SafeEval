package Devel::SafeEval::Defender;
use strict;
use warnings;
use Carp ();

my $SYS_PROTECT_VERSION = 0.02;
my @TRUSTED;
BEGIN {
    @TRUSTED = (
        qw(XSLoader.pm Opcode.pm Math/BigInt/FastCalc.pm), # core modules

        qw(Moose.pm Class/MOP.pm), # Moose related stuff

        qw(threads.pm), # ithreads

        # Encode
        qw(
            Encode.pm Encode/Byte.pm Encode/CN.pm Encode/EBCDIC.pm
            Encode/JP.pm Encode/KR.pm Encode/Symbol.pm Encode/TW.pm
            Encode/Unicode.pm
        ),
    );
};

sub import {
    # XSLoader::load('Sys::Protect', $SYS_PROTECT_VERSION);
    # Sys::Protect->import();

    no warnings 'redefine';
    require DynaLoader;
    *DynaLoader::boot_DynaLoader = sub {
        Carp::croak 'you should not call boot_DynaLoader twice';
        die 'you break a Carp::croak?';
    };

    %ENV = (PATH => '', PERL5LIB => $ENV{PERL5LIB});

    {
        # use kazuho method
        # http://d.hatena.ne.jp/kazuhooku/20090316/1237205628

        my $ix = \&DynaLoader::dl_install_xsub;

        my $trusted_re = do {
            my $t = join '|', @TRUSTED;
            qr{\/(?:$t)$};
        };
        require XSLoader;
        my $xsloader_path = $INC{'XSLoader.pm'};
        my $dynaloader_path = $INC{'DynaLoader.pm'};
        *DynaLoader::dl_install_xsub = sub {
            my $c0 = [caller(0)]->[1];
            my $c1 = [caller(1)]->[1];
            if (($c0 eq $xsloader_path||$c0 eq $dynaloader_path) && $c1 =~ $trusted_re) {
                goto $ix;
            } else {
                die "no xs($c0,$c1)";
            }
        };
    }
}

1;
