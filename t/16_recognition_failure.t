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

TODO: {

todo_skip "No grammar/input devised to test recognition failures yet", 1;

my $expected_recognition_failures = <<EOT;
EOT

is $mp->show_recognition_failures, $expected_recognition_failures, "recognitions failures handled";

}

my $mp1 = Marpa::Easy->new({
    rules => q{
        Expression  ::= Term | Term Op Term
        Term        ::= Factor+
        Factor      ::= Number | LP Expression RP
        Op          ::= '+'
        Number      ::= 'qr/\d+/'
    },
    default_action => 'tree',
    show_recognition_failures => 1,
});

my $tree = $mp1->parse('1+2+1');

say $mp1->show_parse_tree;

done_testing;
