use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'Marpa::Easy';

my $grammar = q{

expression  ::= term  (('+' | '-') term)*
term        ::= factor  (('*'|'/') factor)*
factor      ::= constant | variable | '('  expression  ')'
variable    ::= 'x' | 'y' | 'z'
constant    ::= number+
number      ::= '-'? digit+ ('.' digit+)?
digit       ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'

};

my $ebnf = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'AoA',
});

isa_ok $ebnf, 'Marpa::Easy';

my $numbers = [
    '1234',
    '-1234.423',
    '-1234',
    '1234.423',
];

for my $number (@$numbers){
    my $value = $ebnf->parse($number);
    unless (is $value, $number, "numeral $number lexed and parsed with pure BNF"){
        say $ebnf->show_parse_tree;
    }
}
