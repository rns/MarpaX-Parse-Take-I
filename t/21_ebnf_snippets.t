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

[ q{ s ::= x ( (',' x) | (','? conj x) )* }, <<EOT
0: s -> x s__subrule2*
1: s__subrule0 -> ',' x
2: s__subrule1 -> ',' conj x
3: s__subrule2 -> s__subrule0
4: s__subrule2 -> s__subrule1
5: s__subrule2* -> s__subrule2
6: s__subrule2* -> s__subrule2* s__subrule2
7: s__subrule2* -> /* empty !used */
8: ',' -> /* empty !used */
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
