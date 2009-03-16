package Bot::BasicBot::Pluggable::Module::SafeEval;
use strict;
use warnings;
use base qw(Bot::BasicBot::Pluggable::Module);
use Devel::SafeEval;

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
        substr($res, 0, 100) || 'no output';
    } elsif ($body =~ /^!ever$/) {
        $Devel::SafeEval::VERSION;
    } elsif ($body =~ /^!reload$/) {
        `git pull origin master`;
        require Module::Reload;
        Module::Reload->check;
        "reloaded";
    } elsif ($body =~ /^!cpan\s+([a-zA-Z:_-]+)$/) {
        my $mod = $1;
        if ($mod =~ $badre) {
            "I hate $badre";
        } else {
            join '', `PERL_AUTOINSTALL="--defaultdeps" $^X -MCPAN -Mlocal::lib=/home/dankogai/locallib/ -e 'CPAN::install("$mod")'`;
        }
    }
}

1;
