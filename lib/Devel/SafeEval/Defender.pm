package Devel::SafeEval::Defender;
use strict;
use warnings;
use Carp ();
use Scalar::Util 'refaddr';

my $SYS_PROTECT_VERSION = 0.02;
my @TRUSTED;
BEGIN {
    @TRUSTED = (
        qw(XSLoader Opcode Math::BigInt::FastCalc), # core modules

        qw(Moose Class::MOP), # Moose related stuff

        qw(threads), # ithreads

        # Encode
        qw(
            Encode Encode::Byte Encode::CN Encode::EBCDIC
            Encode::JP Encode::KR Encode::Symbol Encode::TW
            Encode::Unicode
        ),
    );
};

sub import {
    # XSLoader::load('Sys::Protect', $SYS_PROTECT_VERSION);
    # Sys::Protect->import();

    no warnings 'redefine';
    require DynaLoader;
    require XSLoader;
    *DynaLoader::boot_DynaLoader = sub {
        Carp::croak 'you should not call boot_DynaLoader twice';
        die 'you break a Carp::croak?';
    };

    %ENV = (PATH => '', PERL5LIB => $ENV{PERL5LIB});

    {
        # use kazuho method
        # http://d.hatena.ne.jp/kazuhooku/20090316/1237205628

        my $ix = \&DynaLoader::dl_install_xsub;

        my %trusted = map { $_ => 1 } @TRUSTED;
        my $trusted_re = do {
            my $inc = join '|', map { quotemeta $_ } @INC;
            my $t = join '|', map { quotemeta $_ }
                map { s!::!/!g; "$_.pm" }
                @TRUSTED;
            qr{^(?:$inc)\/*(?:$t)$};
        };
        my $orig_xsloader_load = \&XSLoader::load;
        my $orig_dynaloader_bootstrap = \&DynaLoader::bootstrap;
        my $xsloader_path = $INC{'XSLoader.pm'};
        my $dynaloader_path = $INC{'DynaLoader.pm'};
        my $TRUE_INC = join "\0", @INC;
        my $loader_code_hash = sub {
            my $module = shift;
            no strict 'refs';
            my @code = (
                grep { $_ }
                map { DynaLoader->can($_) }
                sort grep /^dl_/,
                keys %{"DynaLoader::"}
            );
            push @code, XSLoader->can('load');
            join("\0", map { refaddr( $_ ) } @code);
        };
        local $^P; # do not use debugger in here
        my $codehash; # predefine
        *XSLoader::load = sub {
            my ($module, ) = @_;
            local $^P; # do not use debugger in here
            die "no xs(${module} is not trusted)" unless $trusted{$module};
            goto $orig_xsloader_load;
        };
        *DynaLoader::bootstrap = sub {
            my ($module, ) = @_;
            die "no xs(${module} is not trusted)" unless $trusted{$module};
            goto $orig_dynaloader_bootstrap;
        };
        *DynaLoader::dl_install_xsub = sub {
            my $c0 = [caller(0)]->[1];
            my $c1 = [caller(1)]->[1];
            if ($TRUE_INC ne join("\0", @INC)) {
                die "do not modify \@INC";
            }
            if ($codehash ne $loader_code_hash->()) {
                die "you changed DynaLoader or XSLoader?";
            }
            if (($c0 eq $xsloader_path||$c0 eq $dynaloader_path) && $c1 =~ $trusted_re) {
                goto $ix;
            } else {
                die "no xs($c0,$c1)";
            }
        };
        $codehash = $loader_code_hash->();
    }
}

1;
