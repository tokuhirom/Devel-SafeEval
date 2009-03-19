package Devel::SafeEval::Defender;
use strict;
use warnings;
use Carp ();
use Scalar::Util ();
use Encode (); # preload Encode.pm

my @TRUSTED;
BEGIN {
    @TRUSTED = (
        # core modules
        qw(XSLoader List::Util Opcode Math::BigInt::FastCalc Time::HiRes Data::Dumper MIME::Base64),

        # popular modules
        qw(Digest::SHA1 JSON::XS),

        # Moose related stuff
        qw(Moose Class::MOP Class::C3::XS Devel::GlobalDestruction Sub::Name B),

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
    require XSLoader;
    require Config;
    my $refaddr = *Scalar::Util::refaddr{CODE};

    package DB; # deny eval-DB.

    %ENV = (PATH => '', PERL5LIB => $ENV{PERL5LIB});

    {
        # use kazuho method
        # http://d.hatena.ne.jp/kazuhooku/20090316/1237205628

        my $loader;
        my $wrapper = sub ($;$) {
            my $alarm = alarm 0;

            if (   tied %SIG
                || tied $SIG{__DIE__}
                || tied $SIG{__WARN__}
                || ref $SIG{__DIE__}  ne ''
                || ref $SIG{__WARN__} ne '' )
            {
                die 'do not tie signal';
            }
            local $SIG{__DIE__}  = 'DEFAULT';
            local $SIG{__WARN__} = 'DEFAULT';

            my $code = $loader->($_[0]);
            $code->(@_) if $code;

            alarm $alarm;
        };

        my $dl_error          = \&DynaLoader::dl_error;
        my $dl_find_symbol    = \&DynaLoader::dl_find_symbol;
        my $dl_findfile       = \&DynaLoader::dl_findfile;
        my $dl_install_xsub   = \&DynaLoader::dl_install_xsub;
        my $dl_load_file      = \&DynaLoader::dl_load_file;
        my $dl_undef_symbols  = \&DynaLoader::dl_undef_symbols;

        my $dlext = $Config::Config{'dlext'};

        my %trusted = map { $_ => 1 } @TRUSTED;
        my $TRUE_INC = join "\0", @INC;
        my $gen_codehash = sub {
            join("\0", map { $refaddr->( $_ ) } @_);
        };
        no warnings 'once';
        my $loader_code = sub {
            my @code = (
                grep { $_ }
                map { *{"DynaLoader::$_"}{CODE} }
                sort grep /^dl_/,
                keys %{"DynaLoader::"}
            );
            push @code, grep { $_ } map { *{"DB::$_"}{CODE} } sort %{"DB::"};
            push @code, *{"XSLoader::load"}{CODE};
            @code;
        };
        my @code; # predefine
        local $^P; # defence from debugger
        # code taken from DynaLoader & XSLoader
        $loader = sub ($) {

            if (tied @_) {
                die 'do not tie @_';
            }
            if (tied %DB::) {
                die 'do not tie %DB::';
            }
            if (tied %DynaLoader::) {
                die 'do not tie %DB::';
            }

            # check the DB first
            if ( $gen_codehash->(@code) ne $gen_codehash->( $loader_code->() ) )
            {
                die "you changed DynaLoader or XSLoader or DB?";
            }

            if (tied @INC) {
                die 'do not tie @INC';
            }
            for (@INC) {
                if (tied $_) {
                    die 'do not tie $INC[n]';
                }
                if (ref $_ ne '') {
                    die 'do not ref $INC[n]';
                }
            }
            if (tied @INC) {
                die 'do not tie @INC';
            }
            if (tied %INC) {
                die 'do not tie %INC';
            }
            for (@_) {
                if (tied $_) {
                    # this check before assign
                    die "tied object is not allowed for module name";
                }
                if (ref $_ ne '') {
                    die 'do not ref $_[n]';
                }
            }

            my $module = $_[0];
            $module = "$module"; # defence: overload hack
            return if $module eq 'Encode'; # Encode is preloaded

            unless (defined $module) {
                die "Usage: DynaLoader::bootstrap(module)";
            }
            die "no xs(${module} is not trusted)" unless $trusted{$module};
            if ( $TRUE_INC ne join( "\0", @INC ) ) {
                die "do not modify \@INC";
            }

            # work with static linking too
            if (defined *{"${module}::bootstrap"}{CODE}) {
                die "bootstrap method is not allowed";
            }

            if (tied ${"${module}::VERSION"}) {
                die "don't tie \$VERSION";
            }
            if (ref ${"${module}::VERSION"}) {
                die "don't ref \$VERSION";
            }

            my @modparts = split( /::/, $module );
            my $modfname = $modparts[-1];

            my $modpname   = join( '/', @modparts );
            my $file = sub {;
                for my $path (@INC) {
                    my $dir = "$path/auto/$modpname";
                    next unless -d $dir;
                    my $try = "$dir/$modfname.${dlext}";
                    if (-f $try) {
                        return $try;
                    }
                }
                return;
            }->();
            die "cannot find $module" unless defined $file;

            my $bootname = "boot_$module";
            $bootname =~ s/\W/_/g;
            local @DynaLoader::dl_require_symbols = ($bootname);

            my $libref = $dl_load_file->( $file, 0 ) or do {
                die "Can't load '$file' for module $module: " . $dl_error->();
            };

            my $boot_symbol_ref = $dl_find_symbol->( $libref, $bootname ) or do {
                die "Can't find '$bootname' symbol in $file\n";
            };

            my $xs = $dl_install_xsub->( "${module}::bootstrap", $boot_symbol_ref,
                $file );

            return $xs;
        };
        undef *XSLoader::load;
        undef *DynaLoader::bootstrap;
        *XSLoader::load = $wrapper;
        *DynaLoader::bootstrap = $wrapper;

        my $fake = sub { die "do not call me" };
        for (grep !/^bootstrap$/, %DynaLoader::) {
            *{"DynaLoader::$_"} = $fake;
        }
        for (grep !/^load$/, %XSLoader::) {
            *{"XSLoader::$_"} = $fake;
        }

        @code = $loader_code->();
    }
}

1;
