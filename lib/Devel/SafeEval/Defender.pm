package Devel::SafeEval::Defender;
use strict;
use warnings;
use Carp ();
use Scalar::Util 'refaddr';
use Digest::MD5 ();

my @TRUSTED;
BEGIN {
    @TRUSTED = (
        qw(XSLoader List::Util Opcode Math::BigInt::FastCalc Time::HiRes Data::Dumper), # core modules

        qw(Moose Class::MOP Class::C3::XS), # Moose related stuff

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
    require DynaLoader;
    require Carp;
    require XSLoader;
    *DynaLoader::boot_DynaLoader = sub {
        Carp::croak 'you should not call boot_DynaLoader twice';
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
            join("\0", map { refaddr( $_ ) } @_);
        };
        my $loader_code = sub {
            no strict 'refs';
            my @code = (
                grep { $_ }
                map { *{"DynaLoader::$_"}{CODE} }
                sort grep /^dl_/,
                keys %{"DynaLoader::"}
            );
            push @code, *{"XSLoader::load"}{CODE};
            @code;
        };
        no strict 'refs';
        my $croak   = *{"Carp::croak"}{CODE};
        my $carp    = *{"Carp::carp"}{CODE};
        my $confess = *{"Carp::confess"}{CODE};
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
            my $file;
            my @dirs;
            foreach (@INC) {

                my $dir = "$_/auto/$modpname";

                next unless -d $dir;    # skip over uninteresting directories

                # check for common cases to avoid autoload of dl_findfile
                my $try = "$dir/$modfname.so";
                last if $file = ( -f $try ) && $try;

                # no luck here, save dir for possible later dl_findfile search
                push @dirs, $dir;
            }

            # last resort, let dl_findfile have a go in all known locations
            $file = $dl_findfile->( map( "-L$_", @dirs, @INC ), $modfname )
              unless $file;

           #   print STDERR "XSLoader::load for $module ($file)\n" if $dl_debug;

            my $bs = $file;
            $bs =~ s/(\.\w+)?(;\d*)?$/\.bs/; # look for .bs 'beside' the library

            goto retry if not -f $file or -s $bs;

            my $bootname = "boot_$module";
            $bootname =~ s/\W/_/g;
            @DynaLoader::dl_require_symbols = ($bootname);

            my $boot_symbol_ref;

            # Many dynamic extension loading problems will appear to come from
            # this section of code: XYZ failed at line 123 of DynaLoader.pm.
            # Often these errors are actually occurring in the initialisation
            # C code of the extension XS file. Perl reports the error as being
            # in this perl code simply because this was the last perl code
            # it executed.

            my $libref = $dl_load_file->( $file, 0 ) or do {
                $croak->(
                    "Can't load '$file' for module $module: " . $dl_error->() );
            };
            push( @DynaLoader::dl_librefs, $libref );    # record loaded object

            my @unresolved = $dl_undef_symbols->();
            if (@unresolved) {
                $carp->(
"Undefined symbols present after loading $file: @unresolved\n"
                );
            }

            $boot_symbol_ref = $dl_find_symbol->( $libref, $bootname ) or do {
                $croak->("Can't find '$bootname' symbol in $file\n");
            };

            push( @DynaLoader::dl_modules, $module );    # record loaded module

          boot:
            my $xs = $dl_install_xsub->( "${module}::bootstrap", $boot_symbol_ref,
                $file );

            # See comment block above
            push( @DynaLoader::dl_shared_objects, $file ); # record files loaded
            return &$xs(@_);

          retry:
            goto &$bootstrap_inherit;
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
