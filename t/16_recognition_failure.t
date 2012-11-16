use 5.010;
use strict;
use warnings;

use YAML;

use Test::More;

use_ok 'MarpaX::Parse';
use_ok 'MarpaX::Parse::Tree';

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
my $mp = MarpaX::Parse->new({
    rules => $grammar,
    default_action => 'MarpaX::Parse::Tree::sexpr',
});

$mp->parse($number);

SKIP: {

skip "No grammar/input devised to test recognition failures yet", 1;

my $expected_recognition_failures = <<EOT;
EOT

is $mp->show_recognition_failures, $expected_recognition_failures, "recognitions failures handled";

}

my $mp1 = MarpaX::Parse->new({
    rules => q{
        Expression  ::= Term | Term Op Term
        Term        ::= Factor+
        Factor      ::= Number | LP Expression RP
        Op          ::= '+'
        Number      ::= 'qr/\d+/'
    },
    default_action => 'MarpaX::Parse::Tree::tree',
    show_recognition_failures => 1,
});

my $tree = $mp1->parse('1+2+1');

say MarpaX::Parse::Tree->new({ type => 'tree' })->show_parse_tree($tree);

done_testing;
