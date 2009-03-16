#!/usr/bin/perl
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

my $uid = 1002;

# -------------------------------------------------------------------------

eval "use $_" for @preload;

my $irc = Bot::BasicBot::Pluggable->new(
    server   => 'irc.freenode.org',
    channels => ['#tttoo'],
    nick     => 'danbot',
);
$irc->load('SafeEval' => {
    timeout => 1,
});
$irc->run;

