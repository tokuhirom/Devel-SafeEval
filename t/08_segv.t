use Test::More;
use Devel::SafeEval;

plan skip_all => 'test segv' unless $ENV{TEST_SEGV};
plan tests => 1;

like(
    Devel::SafeEval->run(
        timeout => 5,
        code    => q!use overload q{""}=>sub{"$_[0]"};$a=bless{},main;"$a"!,
    ),
    qr{signal received: SEGV},
    'handle segv'
);

