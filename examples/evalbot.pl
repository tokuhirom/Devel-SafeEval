use strict;
use warnings;
use POE;
use POE::Component::IRC;
use lib 'lib';
use blib;
use Devel::SafeEval;
use Bot::BasicBot::Pluggable;

# -------------------------------------------------------------------------
# configuration

my %channels = (
    '#tttoo' => ''
);

my @preload = (
    'Moose'
);

# -------------------------------------------------------------------------

eval "use $_" for @preload;

my $irc = Bot::BasicBot::Pluggable->new(
    server   => 'irc.freenode.org',
    channels => ['#tttoo'],
    nick     => 'danbot',
);
$irc->load('SafeEval' => {
    root => '/home/safeeval/',
    timeout => 1,
    uid => $<,
});
$irc->run;

__END__

sub msg (@) { print "[msg] ", "@_\n" }
sub err (@) { print "[err] ", "@_\n" }

msg 'creating irc component';
my $irc = POE::Component::IRC->spawn(
    alias => 'bot',
    server => 'irc.freenode.net',
    nick => 'danbot',
    ircname => 'danbot',
) or die "Couldn't create IRC POE session: $!";

POE::Session->create(
    package_states => [
        main => [qw(_default _start irc_001 irc_public irc_join)]
    ]
);

msg 'starting the kernel';
POE::Kernel->run();
msg 'exiting';
exit 0;

sub _default {
    my ( $event, $args ) = @_[ ARG0 .. $#_ ];
    err "unhandled $event";
    err "  - $_" foreach @$args;
    return 0;
}

sub _start {
    my $heap = $_[HEAP];

    $irc->yield( register => 'all' );
    $irc->yield( connect  => {} );
}

sub irc_001 {
    my $sender = $_[SENDER];

    msg "Connected to ", $irc->server_name();

    while (my ($chan, $key) = each %channels) {
        $irc->yield(join => $chan, $key);
    }
}

sub irc_public {
    my ( $sender, $who, $where, $what ) = @_[ SENDER, ARG0 .. ARG2 ];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

    if ( my ($rot13) = $what =~ /^rot13 (.+)/ ) {
        $irc->yield( privmsg => $channel => "" );
    }
}

sub irc_join {
    my $chan = $_[ARG1];
    $irc->yield( privmsg => $chan => "hi $chan" );
}

