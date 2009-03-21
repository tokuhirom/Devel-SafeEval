use Test::Base;
use Devel::SafeEval;

plan skip_all => 'this test requires JSON::XS' unless eval 'use JSON::XS; 1;';
plan tests => 4;

filters {
    input => [qw/safeeval/]
};

sub safeeval {
    my $src = shift;
    Devel::SafeEval->run(
        timeout => 1,
        code    => $src,
    );
}

run {
    my $block = shift;
    my $res = $block->input;
    eval $block->test;
    die $@ if $@;
};

__END__

=== 
--- input
unpack 'p', 0xdeadbeef;
print 'ok';
--- test
like $res, qr{unpack 'p' is not allowed};
unlike $res, qr{signal};
unlike $res, qr{ok};

=== 
--- input
my $u = unpack('u', '%:&5L;&\`');
print "unpack='$u'";
--- test
like $res, qr{unpack='hello'};

