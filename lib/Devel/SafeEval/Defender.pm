package Devel::SafeEval::Defender;
use strict;
use warnings;
use Carp ();
use Scalar::Util ();

my @TRUSTED;
BEGIN {
    @TRUSTED = (
        qw(XSLoader List::Util Opcode Math::BigInt::FastCalc Time::HiRes Data::Dumper), # core modules

        qw(Moose Class::MOP Class::C3::XS Devel::GlobalDestruction Sub::Name B), # Moose related stuff

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
    no warnings 'redefine';
    no strict 'refs';
    require DynaLoader;
    require Carp;
    require XSLoader;
    my $croak   = *{"Carp::croak"}{CODE};
    my $carp    = *{"Carp::carp"}{CODE};
    my $confess = *{"Carp::confess"}{CODE};
    my $refaddr = *Scalar::Util::refaddr{CODE};
    *DynaLoader::boot_DynaLoader = sub {
        $croak->('you should not call boot_DynaLoader twice');
        die 'you break a Carp::croak?';
    };

    %ENV = (PATH => '', PERL5LIB => $ENV{PERL5LIB});

    {
        # use kazuho method
        # http://d.hatena.ne.jp/kazuhooku/20090316/1237205628

        my $bootstrap_inherit = \&DynaLoader::bootstrap_inherit;
        my $dl_error          = \&DynaLoader::dl_error;
        my $dl_find_symbol    = \&DynaLoader::dl_find_symbol;
        my $dl_findfile       = \&DynaLoader::dl_findfile;
        my $dl_install_xsub   = \&DynaLoader::dl_install_xsub;
        my $dl_load_file      = \&DynaLoader::dl_load_file;
        my $dl_undef_symbols  = \&DynaLoader::dl_undef_symbols;

        my %trusted = map { $_ => 1 } @TRUSTED;
        my $TRUE_INC = join "\0", @INC;
        my $gen_codehash = sub {
            join("\0", map { $refaddr->( $_ ) } @_);
        };
        my $loader_code = sub {
            my @code = (
                grep { $_ }
                map { *{"DynaLoader::$_"}{CODE} }
                sort grep /^dl_/,
                keys %{"DynaLoader::"}
            );
            push @code, *{"XSLoader::load"}{CODE};
            @code;
        };
        my @code; # predefine
        local $^P; # defence from debugger
        # code taken from DynaLoader & XSLoader
        my $loader = sub {
            my ( $module, ) = @_;
            $module = "$module"; # defence: overload hack
            {
                no warnings 'once';
                if (*{"DB::DB"}{CODE}) {
                    die "i hate debugger";
                }
            }
            unless (defined $module) {
                $confess->("Usage: DynaLoader::bootstrap(module)");
            }
            if (tied $module) {
                $croak->("tied object is not allowed for module name");
            }
            die "no xs(${module} is not trusted)" unless $trusted{$module};
            if ( $gen_codehash->(@code) ne $gen_codehash->( $loader_code->() ) )
            {
                die "you changed DynaLoader or XSLoader?";
            }
            if ( $TRUE_INC ne join( "\0", @INC ) ) {
                die "do not modify \@INC";
            }

            # work with static linking too
            my $b = "$module\::bootstrap";
            goto &$b if defined &$b;

            my @modparts = split( /::/, $module );
            my $modfname = $modparts[-1];

            my $modpname   = join( '/', @modparts );
            my $file = sub {;
                for my $path (@INC) {
                    my $dir = "$path/auto/$modpname";
                    next unless -d $dir;
                    my $try = "$dir/$modfname.so";
                    if (-f $try) {
                        return $try;
                    }
                }
                return;
            }->();
            $croak->("cannot find $module") unless defined $file;

            my $bootname = "boot_$module";
            $bootname =~ s/\W/_/g;
            local @DynaLoader::dl_require_symbols = ($bootname);

            my $libref = $dl_load_file->( $file, 0 ) or do {
                $croak->(
                    "Can't load '$file' for module $module: " . $dl_error->() );
            };

            my $boot_symbol_ref = $dl_find_symbol->( $libref, $bootname ) or do {
                $croak->("Can't find '$bootname' symbol in $file\n");
            };

          boot:
            my $xs = $dl_install_xsub->( "${module}::bootstrap", $boot_symbol_ref,
                $file );

            return $xs->(@_);
        };
        *XSLoader::load = $loader;
        *DynaLoader::bootstrap = $loader;

        my $fake = sub { die "do not call me" };
        *DynaLoader::bootstrap_inherit = $fake;
        *DynaLoader::dl_error          = $fake;
        *DynaLoader::dl_find_symbol    = $fake;
        *DynaLoader::dl_findfile       = $fake;
        *DynaLoader::dl_install_xsub   = $fake;
        *DynaLoader::dl_load_file      = $fake;
        *DynaLoader::dl_undef_symbols  = $fake;

        @code = $loader_code->();
    }
}

1;
