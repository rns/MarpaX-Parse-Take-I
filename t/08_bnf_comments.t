use 5.010;
use strict;
use warnings;

use Test::More tests => 4;

use Test::Differences;

use YAML;

use_ok 'MarpaX::Parse';

# tokenize and parse BNF grammar with comments; preserve comments in actions

my $bnf_in_bnf = q{

# grammar starts here (comments starting at line beginning need to be deleted 
# before splitting on balanced

    # start rule
    grammar    ::= production+

    production ::= lhs '::=' rhs
    lhs        ::= symbol
    # this is comment above rhs -> rules production that should be deleted
    rhs        ::= rules
        %{
            # this is action of rhs -> rules production that should not be deleted
            use 5.010; use YAML;
            my $rules = $_[1];
            for my $rule ($rules){
                say "# rule:\n", Dump $rule; # print
            } ## for my $rule ($rules)
        %}
    
    # this is recursive rules+ production
    rules      ::= 
        rule 
            %{
                [ $_[1] ]                   # init separated rule sequence  
            %}
        | 
        rule '|' rules
            %{
                unshift @{ $_[3] }, $_[1];  # prepend next rule, skip separator
                $_[3];                      # return rules aref
            %}

    rule       ::= symbols action? 
        %{ 
            my $res = join ' ', @{ $_[1] };
            $res .= ' + ' . $_[2] if defined $_[2];
            $res;
        %}

    action     ::= 'qr/%{.+?%}/' %{ { action => $_[1] } %}
    
    symbols    ::= 
        symbol
            %{
                [ $_[1] ]                   # init symbol sequence
            %}
        | 
        symbols symbol
            %{ 
                push @{ $_[1] }, $_[2];     # push next symbol
                return $_[1];               # return symbols array
            %}
    
    symbol     ::= literal | identifier

    literal    ::= 'qr/".+?"/' | "qr/'.+?'/"

    identifier ::= 'qr/\w+(\?|\*|\+)?/'
};

my $bnf = MarpaX::Parse->new({
    rules => $bnf_in_bnf,
    default_action => 'AoA',
});

isa_ok $bnf, 'MarpaX::Parse';

my $expected_tokens =
q{identifier: grammar
::=: ::=
identifier: production+
identifier: production
::=: ::=
identifier: lhs
literal: '::='
identifier: rhs
identifier: lhs
::=: ::=
identifier: symbol
identifier: rhs
::=: ::=
identifier: rules
action: %{
            # this is action of rhs -> rules production that should not be deleted
            use 5.010; use YAML;
            my $rules = $_[1];
            for my $rule ($rules){
                say "# rule:\n", Dump $rule; # print
            } ## for my $rule ($rules)
        %}
identifier: rules
::=: ::=
identifier: rule
action: %{
                [ $_[1] ]                   # init separated rule sequence  
            %}
|: |
identifier: rule
literal: '|'
identifier: rules
action: %{
                unshift @{ $_[3] }, $_[1];  # prepend next rule, skip separator
                $_[3];                      # return rules aref
            %}
identifier: rule
::=: ::=
identifier: symbols
identifier: action?
action: %{ 
            my $res = join ' ', @{ $_[1] };
            $res .= ' + ' . $_[2] if defined $_[2];
            $res;
        %}
identifier: action
::=: ::=
literal: 'qr/%{.+?%}/'
action: %{ { action => $_[1] } %}
identifier: symbols
::=: ::=
identifier: symbol
action: %{
                [ $_[1] ]                   # init symbol sequence
            %}
|: |
identifier: symbols
identifier: symbol
action: %{ 
                push @{ $_[1] }, $_[2];     # push next symbol
                return $_[1];               # return symbols array
            %}
identifier: symbol
::=: ::=
identifier: literal
|: |
identifier: identifier
identifier: literal
::=: ::=
literal: 'qr/".+?"/'
|: |
literal: "qr/'.+?'/"
identifier: identifier
::=: ::=
literal: 'qr/\w+(\?|\*|\+)?/'};

eq_or_diff_text $bnf->show_bnf_tokens, $expected_tokens, "BNF text tokenized";

my $expected_rules = 
q{0: grammar -> production+
1: production -> lhs '::=' rhs
2: lhs -> symbol
3: rhs -> rules
4: rules -> rule
5: rules -> rule '|' rules
6: rule -> symbols action
7: action -> 'qr/%{.+?%}/'
8: symbols -> symbol
9: symbols -> symbols symbol
10: symbol -> literal
11: symbol -> identifier
12: literal -> 'qr/".+?"/'
13: literal -> "qr/'.+?'/"
14: identifier -> 'qr/\w+(\?|\*|\+)?/'
15: production+ -> production+
16: rule -> symbols};

eq_or_diff_text $bnf->show_rules, $expected_rules, "BNF with comments transformed into Marpa rules";

