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
        my $xsloader_path = $INC{'XSLoader.pm'};
        my $dynaloader_path = $INC{'DynaLoader.pm'};
        my $TRUE_INC = join "\0", @INC;
        my $gen_codehash = sub {
            join("\0", map { refaddr( $_ ) } @_);
        };
        my $loader_code = sub {
            my $module = shift;
            no strict 'refs';
            my @code = (
                grep { $_ }
                map { DynaLoader->can($_) }
                sort grep /^dl_/,
                keys %{"DynaLoader::"}
            );
            push @code, XSLoader->can('load');
            push @code, Carp->can('croak');
            @code;
        };
        my $croak = Carp->can('croak');
        my $carp = Carp->can('carp');
        my $confess = Carp->can('confess');
        no strict 'refs';
        my @code; # predefine
        local $^P; # defence from debugger
        my $loader = sub {
            my ( $module, ) = @_;
            $module = "$module"; # defence: overload hack
            unless ($module) {
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

            die q{XSLoader::load('Your::Module', $Your::Module::VERSION)}
              unless @_;

            # work with static linking too
            my $b = "$module\::bootstrap";
            goto &$b if defined &$b;

            goto retry unless $module and defined &DynaLoader::dl_load_file;

            my @modparts = split( /::/, $module );
            my $modfname = $modparts[-1];

            my $modpname   = join( '/', @modparts );
            my $modlibname = ( caller() )[1];
            my $c          = @modparts;
            $modlibname =~ s,[\\/][^\\/]+$,, while $c--;    # Q&D basename
            my $file = "$modlibname/auto/$modpname/$modfname.so";

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

            my $libref = DynaLoader::dl_load_file( $file, 0 ) or do {
                $croak->(
                    "Can't load '$file' for module $module: " . DynaLoader::dl_error() );
            };
            push( @DynaLoader::dl_librefs, $libref );    # record loaded object

            my @unresolved = DynaLoader::dl_undef_symbols();
            if (@unresolved) {
                $carp->(
"Undefined symbols present after loading $file: @unresolved\n"
                );
            }

            $boot_symbol_ref = DynaLoader::dl_find_symbol( $libref, $bootname ) or do {
                $croak->("Can't find '$bootname' symbol in $file\n");
            };

            push( @DynaLoader::dl_modules, $module );    # record loaded module

          boot:
            my $xs = $ix->( "${module}::bootstrap", $boot_symbol_ref,
                $file );

            # See comment block above
            push( @DynaLoader::dl_shared_objects, $file ); # record files loaded
            return &$xs(@_);

          retry:
            my $bootstrap_inherit = DynaLoader->can('bootstrap_inherit')
              || XSLoader->can('bootstrap_inherit');
            goto &$bootstrap_inherit;
        };
        *XSLoader::load = $loader;
        *DynaLoader::bootstrap = $loader;
        *DynaLoader::dl_install_xsub = sub {
            die "do not call me";
        };
        @code = $loader_code->();
    }
}

1;
