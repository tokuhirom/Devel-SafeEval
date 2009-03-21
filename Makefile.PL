use inc::Module::Install;
name 'Devel-SafeEval';
all_from 'lib/Devel/SafeEval.pm';

requires 'Sys::Protect';
requires 'IPC::Open3';
requires 'BSD::Resource';
requires 'Params::Validate';
my $cflags = $ENV{USER} eq 'tokuhirom' ? '-Wall --std=c89' : '';
can_cc or die "This module requires a C compiler";
makemaker_args(
    OBJECT => '$(O_FILES)',
    CCFLAGS => $cflags,
    clean => {
        FILES => q{
            *.stackdump
            *.gcov *.gcda *.gcno
            *.out
            nytprof
            cover_db
        },
    },
);

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
