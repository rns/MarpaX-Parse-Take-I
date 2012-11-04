use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'Marpa::Easy';

my $grammar = q{

    expression  ::= term  ( ( '+' | '-' ) term )*
    term        ::= factor  ( ( '*' | '/' ) factor)*
    factor      ::= constant | variable | '('  expression  ')'
    variable    ::= 'x' | 'y' | 'z'
    constant    ::= digit+ ('.' digit+)?
    digit       ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'

};

my $ebnf = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr',
    ebnf => 1,
#    show_tokens => 1,
    quantifier_rules => 'recursive',
    nullable_quantified_symbols => 1,
});

say $ebnf->show_rules();

isa_ok $ebnf, 'Marpa::Easy';

my $expressions = [
# numbers
    '1234.132',
    '-1234',
# actions
    '1234 + 4321',
    '(1234 + 1234) / 123',
# variables
    'x + 1',
    '(x + 1) + 2',
    '((x + 1) / 4) + 2',
    '(x + y) / z) + 2'
];

use XML::Twig;

for my $expression (@$expressions){
    my $value = $ebnf->parse($expression);
    
#    say Dump $value;
    
    unless (is $value, $expression, "expression $expression lexed and parsed with EBNF"){
        say $ebnf->show_parse_tree;
    }
}
