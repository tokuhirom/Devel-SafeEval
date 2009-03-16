package Devel::SafeEval::Defender;
use strict;
use warnings;
use Safe;

my $SYS_PROTECT_VERSION = 0.02;
my @TRUSTED;
BEGIN {
    @TRUSTED = qw(Moose.pm XSLoader.pm Encode.pm);
};

sub import {
    # XSLoader::load('Sys::Protect', $SYS_PROTECT_VERSION);
    # Sys::Protect->import();

    no warnings 'redefine';
    require DynaLoader;
    *DynaLoader::boot_DynaLoader = sub {
        Carp::croak 'you should not call boot_DynaLoader';
        die 'you break a Carp::croak?';
    };

    %ENV = (PATH => '', PERL5LIB => $ENV{PERL5LIB});

    {
        # use kazuho method
        # http://d.hatena.ne.jp/kazuhooku/20090316/1237205628
        no warnings qw(redefine);
        my %trusted =
          map { $_ => 1 } @TRUSTED;

        my $ix = \&DynaLoader::dl_install_xsub;
        my $fake = sub { die "no xs\n" };
        *DynaLoader::dl_install_xsub = $fake;
        my @trueINC;

        unshift @INC, sub {
            shift;
            my $module = "$_[0]"; # barrier for overload-stringify attack
            die "\@INC has been modified\n"
              unless "@INC" eq "@trueINC";
            return undef ## no critic
              unless $trusted{$module} && \&DynaLoader::dl_install_xsub != $ix;
            eval {
                *DynaLoader::dl_install_xsub = $ix;
                require $module;
            };
            *DynaLoader::dl_install_xsub = $fake;
            die $@ if $@;
            return 1;
        };

        @trueINC = @INC;
    }
}

1;
