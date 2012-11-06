use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'MarpaX::Parse';

my $grammar = q{

    expression  ::= term  ( ( '+' | '-' ) term )*
    term        ::= factor  ( ( '*' | '/' ) factor)*
    factor      ::= constant | variable | '('  expression  ')'
    variable    ::= 'x' | 'y' | 'z' | 'a' | 'b'
    constant    ::= digit+ ('.' digit+)?
    digit       ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    
};

my $ebnf = MarpaX::Parse->new({
    rules => $grammar,
    default_action => 'AoA',
    ebnf => 1,
    quantifier_rules => 'recursive',
    nullables_for_quantifiers => 1,
});

say $ebnf->show_rules;

isa_ok $ebnf, 'MarpaX::Parse';

my $tests = [

# numbers

    [   '1234.132',             
        "[['1','2','3','4'],['.',['1','3','2']]]" ],

    [   '-1234',                
        "['1','2','3','4']" ],

# actions

    [   '1234 + 4321',          
        "[['1','2','3','4'],[['+',['4','3','2','1']]]]" ],

    [   '(1234 + 1234) / 123',  
        "[['(',[['1','2','3','4'],[['+',['1','2','3','4']]]],')'],[['/',['1','2','3']]]]" ],

# variables

    [   'x + 1',                
        "['x',[['+',['1']]]]" ],

    [   '(x + 1) + 2',          
        "[['(',['x',[['+',['1']]]],')'],[['+',['2']]]]" ],

    [   '((x + 1)/4) + 2',      
        "[['(',[['(',['x',[['+',['1']]]],')'],[['/',['4']]]],')'],[['+',['2']]]]" ],

    [   '(x + y)/z + 2',          
        "[[['(',['x',[['+','y']]],')'],[['/','z']]],[['+',['2']]]]" ],

    [   '((a + b)/((x + y)/z))+2',
        "[['(',[['(',['a',[['+','b']]],')'],[['/',['(',[['(',['x',[['+','y']]],')'],[['/','z']]],')']]]],')'],[['+',['2']]]]" ],
];

use XML::Twig;

use Data::Dumper;
$Data::Dumper::Terse = 1;          # don't output names where feasible
$Data::Dumper::Indent = 0;         # turn off all pretty print

use Data::Dump qw{ dump };

for my $test (@$tests){

    my ($expr, $expected) = @$test;

    my $value = $ebnf->parse($expr);
    
    unless (is Dumper($value), $expected, "expression $expr lexed and parsed with EBNF"){
#        say $ebnf->show_parse_tree;
        say Dumper $value;
    }

}
