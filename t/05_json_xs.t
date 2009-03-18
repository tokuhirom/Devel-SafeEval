use Test::Base;
use Devel::SafeEval;

plan skip_all => 'this test requires JSON::XS' unless eval 'use JSON::XS; 1;';
plan tests => 2;

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
package F;
use base qw(Tie::Scalar);
sub TIESCALAR { bless {} }

sub FETCH {
    eval 'package 
                DB;sub f { eval q{$dl_install_xsub->()}; warn $@ }';
    goto &DB::f;
}
tie $JSON::XS::VERSION, 'F';
XSLoader::load("JSON::XS")
--- test
unlike $res, qr{dl_install_xsub};
like $res, qr{don't tie \$module};
