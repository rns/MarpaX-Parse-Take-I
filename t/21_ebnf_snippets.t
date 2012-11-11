use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'MarpaX::Parse';

for my $data (

[   
    q{
        greeting ::= ('Hi' | 'Hello' | 'hi' | 'hello' ) comma? (world | me | others)? 
            %{ 
#                say Dump \@_;
                shift;
                my ($hello, $comma, $name) = @_;
                if ($comma){
                    join ' ', "$hello,", $name eq "parser" ? "world" : "I'm not $name, I'm parser";
                }
                elsif ($name eq "parser") {
                    "$hello me? $hello you!"
                }
                else {
                    "$hello $name? How come?"
                }
            %}
        world ::= 'world'
        me    ::= 'parser'
        others ::= 'qr/\w+/'
        comma ::= ','

    }, 
    undef, 
    [ 'Hello, parser',  'Hello parser',         'Hello, fred',                     'Hello fred' ], 
    [ 'Hello, world',   'Hello me? Hello you!', "Hello, I'm not fred, I'm parser", 'Hello fred? How come?' ]
],

[
    q{ r ::= s1 s2 r1 }, q{0: r -> s1 s2 r1},
],

[ 
    q{ r ::= s1 s2 r1 %{ %} r1 ::= s1 }, <<EOT
0: r -> s1 s2 r1
1: r1 -> s1
EOT
],

[ q{ 
    sz ::= sx sy
    sx ::= x ( (',' x) | (','? conj x) )* 
    sy ::= y ( (',' y) | (','? conj y) )*
}, <<EOT
0: sz -> sx sy
1: sx -> x sx__subrule1.2*
2: sx__subrule1.0 -> ',' x
3: sx__subrule1.1 -> ',' conj x
4: sx__subrule1.2 -> sx__subrule1.0
5: sx__subrule1.2 -> sx__subrule1.1
6: sy -> y sy__subrule2.2*
7: sy__subrule2.0 -> ',' y
8: sy__subrule2.1 -> ',' conj y
9: sy__subrule2.2 -> sy__subrule2.0
10: sy__subrule2.2 -> sy__subrule2.1
11: sx__subrule1.2* -> sx__subrule1.2
12: sx__subrule1.2* -> sx__subrule1.2* sx__subrule1.2
13: sy__subrule2.2* -> sy__subrule2.2
14: sy__subrule2.2* -> sy__subrule2.2* sy__subrule2.2
15: ',' -> /* empty !used */
16: sy__subrule2.2* -> /* empty !used */
17: sx__subrule1.2* -> /* empty !used */
EOT
],
    
    ){
    my ($grammar, $rules, $input, $output) = @$data;
    
    ($input, $output) = map { not (ref $_) ? [ $_ ] : $_ } ($input, $output);
    
    my $ebnf = MarpaX::Parse->new({
        rules => $grammar,
        quantifier_rules => 'recursive',
        nullables_for_quantifiers => 1,
    }) or die "Can't creat grammar: $@";
    
#    say $ebnf->show_rules;
    
    # test the rules the grammar is parsed to
    if (defined $rules){
        ($grammar, $rules) = map { s/^\s+//; s/\s+$//; $_ } ($grammar, $rules);
        unless (is my $got_rules = $ebnf->show_rules, $rules, "parsed '$grammar' to rules"){
            say $got_rules;
        }
    }
    
    # skip empty output
    # test if out=p(in)
    for my $i (0..@$input-1){
        my ($in, $out) = map { $_->[$i] } ($input, $output);
        next unless $in and $out;
        unless (is my $got = $ebnf->parse($in) || 'No parse.', $out, "parsed '$in' to '$out' using EBNF with embedded actions"){
            say Dump $got;            
        }
    }
}

done_testing;
