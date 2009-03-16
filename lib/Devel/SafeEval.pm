package Devel::SafeEval;
use strict;
use warnings;
our $VERSION = '0.07';
our @ISA;
use BSD::Resource 'setrlimit';
use Params::Validate ':all';
use IPC::Open3;
use XSLoader;
use Time::HiRes 'alarm';
use Carp ();
use DynaLoader;
use File::Temp;
require Devel::SafeEval::Defender;

# XSLoader::load(__PACKAGE__, $VERSION);

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
            code    => 1,
            timeout => 1,
            perl    => {
                default => $^X,
            },
            rlimit_nofile  => {
                default => 7,
            },
            arguments => {
                default => [],
            },
        }
    );

    local $@;
    my $ret = eval {
        $class->_body(%args);
    };
    if (my $e = $@) {
        return $e;
    } else {
        return $ret;
    }
}

sub _body {
    my ($class, %args) = @_;

    if ($args{code} =~ /^#line/m) {
        return '#line is not allowed';
    }

    my $tmp = File::Temp->new(UNLINK => 1);
    my $pid = -1;
    local $@;
    my $stdout = '';
    eval {
        my $deny = join ',', qw{
            stat lstat readlink
            ftatime ftblk ftchr ftctime fteexec fteowned
            fteread ftewrite ftfile ftis ftlink ftmtime ftpipe
            ftrexec ftrowned ftrread ftsgid ftsize ftsock ftsuid
            fttty ftzero ftrwrite ftsvtx
            fttext ftbinary
        };
        my @args = (q{-M-ops=:subprocess,:filesys_write,exec,kill,chdir,open,:sys_db,:filesys_open,:others,dofile,bind,connect,listen,accept,shutdown,gsockopt,getsockname,flock,ioctl,reset,dbstate,:dangerous,} . $deny);
        local $SIG{ALRM} = sub { die "timeout" };
        alarm $args{timeout};
        $pid = open3( my ( $wfh, $rfh, $efh ),
            $args{perl}, '-Ilib', '-MDevel::SafeEval::Defender', @{ $args{arguments} },
            @args);
        local $SIG{CHLD} = sub { waitpid($pid, 0) };
        print $wfh $args{code};
        close $wfh;
        local $/;
        $stdout = <$rfh>;
        close $rfh;
        alarm 0;
    };
    kill 9 => $pid if $pid > 0;
    if (my $e = $@) {
        return $e;
    } else {
        return $stdout;
    }
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
      uid  => 1,
  );

=head1 DESCRIPTION

Devel::SafeEval is

=head1 MEMO

call chroot(2) before use this module.

=head1 CAUTION

THIS MODULE IS NOT A SAFETY

=head1 SECURITY

    - mask op code
    - trash DynaLoader::dl_install_xsub

=head1 TODO

    close all files

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom ah! gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
