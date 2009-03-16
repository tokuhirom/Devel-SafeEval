package Devel::SafeEval::Defender;
use strict;
use warnings;
use Safe;

my $SYS_PROTECT_VERSION = 0.02;


sub import {
    XSLoader::load('Sys::Protect', $SYS_PROTECT_VERSION);
    Sys::Protect->import();

    no warnings 'redefine';
    require DynaLoader;
    *DynaLoader::boot_DynaLoader = sub {
        Carp::croak 'you should not call boot_DynaLoader';
        die 'you break a Carp::croak?';
    };
    *DynaLoader::dl_install_xsub = sub {
        Carp::croak "do not load xs";
        die 'you break a Carp::croak?';
    };

    %ENV = ();
}

1;
