use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'MarpaX::Parse';

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
[ 
    q{ r ::= s1 s2 r1 }, <<EOT
0: r -> s1 s2 r1
EOT
],

[ 
    q{ r ::= s1 s2 r1 r1 ::= s1 }, <<EOT
0: r -> s1 s2 r1
1: r1 -> s1
EOT
],

[ q{ 
    s ::= x ( (, x) | (,? conj x) )* 
#    s1 ::= x ( (, x) | (,? conj x) )*
}, '' ],
    
    ){
    my ($grammar, $rules) = @$data;

    my $ebnf = MarpaX::Parse->new({
        rules => $grammar,
        ebnf => 1,
#        show_tokens => 1,
    });
    
    my $got_rules = $ebnf->show_rules;
    unless (is "$got_rules\n", $rules, "parsed $grammar"){
        say $got_rules;
    }
}

done_testing;
