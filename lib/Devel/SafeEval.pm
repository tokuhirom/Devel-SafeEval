package Devel::SafeEval;
use strict;
use warnings;
our $VERSION = '0.01';
our @ISA;
use POSIX;
use BSD::Resource 'setrlimit';
use Params::Validate ':all';
use IPC::Open3;
use Symbol;
use XSLoader;
use Proc::Wait3;
use Time::HiRes 'alarm';
use Carp ();

my $SYS_PROTECT_VERSION = 0.02;

XSLoader::load(__PACKAGE__, $VERSION);

# linux :)
use constant {
    RLIMIT_FSIZE    => 1,
    RLIMIT_CORE     => 4,
    RLIMIT_NOFILE   => 7,
    RLIMIT_AS       => 9,
    RLIMIT_MSGQUEUE => 12,
};

sub run {
    my $class = shift;
    my %args = validate(
        @_ => {
            root    => 0,
            code    => 1,
            uid     => 1,
            timeout => 1,
            perl    => {
                default => $^X,
            },
            rlimit_nofile  => {
                default => 7,
            },
        }
    );

    my $ret = eval {
        local $SIG{ALRM} = sub { die 'timeout' };
        alarm $args{timeout};
        my ($pid, $ret) = $class->_body(%args);
        alarm 0;
        kill 9, $pid;
        $ret;
    };
    if ($@) {
        return $@;
    } else {
        return $ret;
    }
}

sub _body {
    my ($class, %args) = @_;

    my ($cout, $pout) = (gensym(), gensym());
    pipe($pout, $cout) or die $!;

    my $pid = fork();
    if ($pid == 0) {
        # child
        close $pout;
        eval {
            $class->_run_child($cout, %args);
        };
        print $@ if $@;
        exit;
    } elsif (! defined $pid) {
        die "cannot fork: $!";
    } else {
        close $cout;

        local $SIG{CHLD} = sub { waitpid($pid, 0) };
        wait3(1);
        my $out = join '', <$pout>;
        return ($pid, $out);
    }
}

sub _run_child {
    my ($class, $cout, %args) = @_;

    close STDIN;
    close STDOUT;
    close STDERR;

    open STDOUT, '>&=' . fileno($cout);
    open STDERR, '>&=' . fileno($cout);

    select STDERR; $| = 1;
    select STDOUT; $| = 1;

    POSIX::setuid($args{uid}) or die $!;

    XSLoader::load('Sys::Protect', $SYS_PROTECT_VERSION);
    Sys::Protect->import();

    no warnings 'redefine';
    *DynaLoader::dl_install_xsub = sub {
        Carp::croak "do not load xs";
        die 'you break a Carp::croak?';
    };

    Internals::SvREADONLY(@INC, 1);

    if (exists $args{'root'}) {
        chdir($args{'root'}) or die $!;
        chroot($args{'root'}) or die $!;
    }

    setrlimit(RLIMIT_AS, 10*1024*1024, 10*1024*1024);
    setrlimit(RLIMIT_FSIZE, 0, 0);
    setrlimit(RLIMIT_MSGQUEUE, 0, 0);
    setrlimit(RLIMIT_NOFILE, $args{rlimit_nofile}, $args{rlimit_nofile});

    %ENV = ();

    eval $args{code}; ## no critic
    print STDERR $@ if $@;
    exit(0);
}

1;
__END__

=head1 NAME

Devel::SafeEval -

=head1 SYNOPSIS

  use Devel::SafeEval;
  Devel::SafeEval->run(
      code => 'fork()',
      timeout => 1,
      root => '/path/to/root',
      uid  => 1,
  );

=head1 DESCRIPTION

Devel::SafeEval is

=head1 CAUTION

THIS MODULE IS NOT A SAFETY

=head1 SECURITY

    - mask op code
    - trash DynaLoader::dl_install_xsub

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom ah! gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
