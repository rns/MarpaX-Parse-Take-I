use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'Marpa::Easy';

my $ebnf_in_bnf = q{

  grammar       ::= production+
  production    ::= lhs '::=' rhs

  lhs ::= symbol

  rhs ::= 

    term

        %{ [ $_[1] ] %} |

    term '|' rhs

        %{ unshift @{ $_[3] }, $_[1]; $_[3] %}
        
  term          ::= factor+ action?

  action        ::= 'qr/%{.+?%}/'

  factor        ::= 

    symbol | 
    '(' rhs ')' |
    '(' identifier ':' rhs ')'
  
  factor        ::= factor quantifier 
  factor        ::= factor action
    
  quantifier    ::= '?' | '*' | '+' 

  symbol        ::= identifier | literal
  identifier    ::= 'qr/[\w\d\-]+/'
  literal       ::= 'qr/".+?"/' | "qr/'.+?'/"
    
};

my $ebnf_bnf = Marpa::Easy->new({
    rules => $ebnf_in_bnf,
    default_action => 'AoA',
    show_bnf_tokens => 1,
});

isa_ok $ebnf_bnf, 'Marpa::Easy';

say $ebnf_bnf->show_rules;

# example grammar (comments are not supported yet)
my $arithmetic = q{
    expression  ::= 

        term                            

            %{ term-action %}           

        ( (AddSubOp: '+' | '-' ) %{ term-op named subrule action %} term )* 
            
            %{ *-factor-action %} 
            
        %{ expression-action %}
        
    term        ::= factor  ( (MulDivOp: '*' | '/' ) factor)*
    factor      ::= constant | variable | '('  expression  ')'
    variable    ::= 'x' | 'y' | 'z'
    constant    ::= digit+ (frac:'.' digit+)?
    digit       ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' %{ 9-action %}
};

my $arithmetic_rules = $ebnf_bnf->parse($arithmetic);

say $ebnf_bnf->show_parse_tree;

# set up decimal number bnf
my $arithmetic_bnf = Marpa::Easy->new({
    rules => $arithmetic_rules,
    default_action => 'AoA_with_rule_signatures',
    show_bnf_tokens => 1,
});

# test decimal number bnf
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

for my $expr (@$expressions){

    # parse tree is in XML string (default_action => 'xml')
    my $value = $arithmetic_bnf->parse($expr);

    unless (is $value, $expr, "expression $expr lexed and parsed with EBNF"){
        $arithmetic_bnf->show_parse_tree;
    }
}
