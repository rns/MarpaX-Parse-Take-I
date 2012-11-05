use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'Marpa::Easy';

=pod EBNF syntax 

Wirth

    Production  = Identifier "=" Expression ".".
    Expression  = Term {"|" Term }.
    Term        = Factor {Factor}.
    Factor      = Identifier | "'" String "'" | '"' String '"' | 
                  "(" Expression ")" | "[" Expression "]" | "{" Expression "}".
    Identifier  = String .
    String      = Char { Char }.
    Char        = "A" | .. | "Z" | "a" | .. | "z" | "0" | .. | "9"

?+*-notation minus 

    Production  ::= Identifier "::=" Expression
    Expression  ::= Term ("|" Term )*
    Term        ::= Factor {Factor}
    Factor      ::= Identifier | "'" String "'" | '"' String '"' | 
                  "(" Expression ")" | "[" Expression "]" | "{" Expression "}"
    Identifier  ::= String .
    String      ::= Char { Char }.
    Char        ::= "A" | .. | "Z" | "a" | .. | "z" | "0" | .. | "9"

=cut

for my $data (
    [ 'rule ::= sym1 sym2 rule1', '' ],
    [ 'rule ::= sym1 sym2 rule1 rule1 ::= sym1', '' ],
    ){
    my ($grammar, $rules) = @$data;

    my $ebnf = Marpa::Easy->new({
        rules => $grammar,
        ebnf => 1,
#        show_tokens => 1,
    });

    say $ebnf->show_rules;
}

