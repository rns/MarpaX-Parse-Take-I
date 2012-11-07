use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'MarpaX::Parse';

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
    s ::= x ( (',' x) | (','? conj x) )* 
}, '' ],
    
    ){
    my ($grammar, $rules) = @$data;

    my $ebnf = MarpaX::Parse->new({
        rules => $grammar,
        ebnf => 1,
        show_tokens => 1,
        quantifier_rules => 'recursive',
        nullables_for_quantifiers => 1,
    });
    
    my $got_rules = $ebnf->show_rules;
    unless (is "$got_rules\n", $rules, "parsed $grammar"){
        say $got_rules;
    }
}

done_testing;
