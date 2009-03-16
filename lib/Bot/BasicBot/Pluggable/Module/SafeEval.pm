package Bot::BasicBot::Pluggable::Module::SafeEval;
use strict;
use warnings;
use base qw(Bot::BasicBot::Pluggable::Module);
use Devel::SafeEval;

sub told {
    my ($self, $msg) = @_;
    my $body = $msg->{body};
    return 0 unless defined $body;

    if ($body =~ /^!eval\s+(.+)$/) {
        my $code = $1;
        print "evaluating $code\n";
        my $opts = $self->{Param}->[0];
        Devel::SafeEval->run(
            %$opts,
            code => $code,
        );
    }
}

1;
