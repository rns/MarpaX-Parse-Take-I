use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'Marpa::Easy';

my $grammar = q{

    # expression
    expr ::= # expression
        '-' num 
        %{ 
            $_[1] .                 # negation
            $_[2]                   # number
        %} 
        | 
        num
        %{ 
            $_[1]                   # positive number
        %} 
# num
    num ::= 
        digits
        %{ 
            join('', @{$_[1]})      # integer
        %} 
        |
        digits '.' digits
        %{ 
            join('', @{$_[1]})  .   # integer part
            $_[2]               .   # decimal point
            join('', @{$_[3]})      # fractional part
        %}
    digits ::= 
        digit
        %{ 
            [ $_[1] ]               # first digit: array setup
        %}
        | 
        digits digit
        %{ 
            push @{$_[1]}, $_[2];   # push next digit
            $_[1];                  # return digits array
        %}
    digit ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    
};

my $bnf = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'AoA',
});

isa_ok $bnf, 'Marpa::Easy';

my $numbers = [
    '1234',
    '-1234.423',
    '-1234',
    '1234.423',
];

for my $number (@$numbers){
    my $value = $bnf->parse($number);
    is $value, $number, "numeral $number lexed and parsed with pure BNF";
}
