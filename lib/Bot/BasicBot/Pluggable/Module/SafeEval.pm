package Bot::BasicBot::Pluggable::Module::SafeEval;
use strict;
use warnings;
use base qw(Bot::BasicBot::Pluggable::Module);
use Devel::SafeEval;
use Cwd ();

my $badre = qr/^(?:Devel::|B::|Acme::|IO::|IPC::|File::|PadWalker::|PeekPoke)/;

sub told {
    my ($self, $msg) = @_;
    my $body = $msg->{body};
    return 0 unless defined $body;

    if ($body =~ /^!eval\s+(.+)$/) {
        my $code = $1;
        print "evaluating $code\n";
        my $opts = $self->{Param}->[0];
        delete $opts->{arguments};
        my $res = Devel::SafeEval->run(
            %$opts,
            code => $code,
        );
        substr($res, 0, 512) || 'no output';
    } elsif ($body =~ /^!ever$/) {
        $Devel::SafeEval::VERSION;
    } elsif ($body =~ /^!reload$/) {
        `git pull origin master`;
        `make`;
        require Module::Reload;
        Module::Reload->check;
        "reloaded";
    } elsif ($body =~ /^!make$/) {
       `make`;
    } elsif ($body =~ /^!cpan-mkmyconfig$/) {
        require CPAN::FirstTime;
        require CPAN;
        my $cpanpm = '/home/dankogai/.cpan/CPAN/MyConfig.pm';
        File::Path::mkpath(File::Basename::dirname($cpanpm)) unless -e $cpanpm;
        $CPAN::Config ||= {};
        $CPAN::Config = {
            %$CPAN::Config,
            build_dir         => undef,
            cpan_home         => undef,
            keep_source_where => undef,
            histfile          => undef,
        };
        CPAN::FirstTime::init($cpanpm, ());
    } elsif ($body =~ /^!cpan\s+([a-zA-Z:_-]+)$/) {
        my $mod = $1;
        if ($mod =~ $badre) {
            "I hate $badre";
        } else {
            my $cwd = Cwd::cwd();
            require CPAN;
            require Module::Install;
            local::lib->import('/home/dankogai/locallib/');
            $ENV{HOME} = '/home/dankogai/';
            $ENV{PERL_AUTOINSTALL} = '--defaultdeps';
            my $msg = CPAN::Shell->install($mod) || '';
            chdir($cwd); # restore cwd
            "installed $mod($msg)";
        }
    } elsif ($body =~ /^!modules\s+(\S+)$/) {
        my $dir = $1;
        return 'directory traversal' if $dir =~ /\.\./;
        my @d;
        opendir my $d, "/home/dankogai/locallib/$1" or die $!;
        push @d, $_ for readdir($d);
        closedir($d);
        return "@d";
    }
}

1;
