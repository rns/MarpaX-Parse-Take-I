use 5.010;
use strict;
use warnings;

use YAML;

use Test::More;

use Marpa::Easy;

# grammar
my $grammar = q{

    expr    ::= num | minus num

    num     ::= digits | digits point digits
    digits  ::= digit | digit digits

    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    point   ::= '.'
    minus   ::= '-' 
};

# input
my $number = '-1234.423'; 

# set up the grammar
my $mp = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr',
});

$mp->parse($number);

my $expected = <<EOT;
# tokens:
'-': -
'1': 1
'2': 2
'3': 3
'4': 4
'.': .
'4': 4
'2': 2
'3': 3
::any: , 1123
EOT

$mp->parse($number);

eval { $mp->parse($number) } ; warn $@ if $@;

# TODO: produce non-fatal errors to test recognition_failure_sub
diag "recognition_failures:\n", $mp->show_recognition_failures;

done_testing;
