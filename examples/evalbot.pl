#!/usr/bin/perl
use strict;
use warnings;
use File::Spec;
use FindBin;
use local::lib '/home/dankogai/locallib/';
use lib File::Spec->catfile($FdinBin::Bin, 'lib');
use POE;
use POE::Component::IRC;
use Devel::SafeEval;
use Bot::BasicBot::Pluggable;

# -------------------------------------------------------------------------
# configuration

my %channels = (
    '#tttoo' => ''
);

my $uid = 1002;

# -------------------------------------------------------------------------

my $irc = Bot::BasicBot::Pluggable->new(
    server   => 'irc.freenode.org',
    channels => ['#tttoo'],
    nick     => 'danbot',
);
$irc->load(
    'SafeEval' => {
        timeout   => 1,
        arguments => ['-Mlocal::lib=/home/dankogai/locallib/'],
    }
);
$irc->run;
