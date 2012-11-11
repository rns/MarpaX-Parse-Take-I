use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'MarpaX::Parse';

=head1 The Idea

    macro expansion for EBNF C preprocessor
    
    s(x) ::= x x x x
    x ::= A
    x ::= B
    
        ->
        
    s(A) ::= A A A A A
    s(B) ::= B B B B B

    s(x y) ::= xy xy xy x y
    x ::= A
    y ::= B               

    s(A B) ::= AB AB AB A B
    
=cut

for my $data (

[
    q{ r ::= s1 s2 r1 }, q{0: r -> s1 s2 r1}, []. []
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
