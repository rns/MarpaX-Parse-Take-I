use 5.010;
use strict;
use warnings;

use YAML;
use Test::More;

use Test::Output;

use Marpa::Easy;

# grammar
my $grammar = q{
    expr    ::= '-' num | num
    num     ::= digits | digits '.' digits
    digits  ::= digit | digit digits
    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
};

my $bnf = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr',
});

# input
my $number = '-1234.423'; 

my $number_tokens = [
    [ '-', '-' ],
    [ '1', '1' ],
    [ '2', '2' ],
    [ '3', '3' ],
    [ '4', '4' ],
    [ '.', '.' ],
    [ '4', '4' ],
    [ '2', '2' ],
    [ '3', '3' ],
];

# parse
my $sexpr = $bnf->parse($number);

unless (is $sexpr, '(expr - (num (digits (digit 1) (digits (digit 2) (digits (digit 3) (digits (digit 4))))) . (digits (digit 4) (digits (digit 2) (digits (digit 3))))))', "$number parsed"){
    say $sexpr;
}

# get the expected output by setting options and calling option methods directly
for my $data (
# option, value
[ 'symbols', q{0: expr
1: '-', terminal
2: num
3: digits
4: '.', terminal
5: digit
6: '0', terminal
7: '1', terminal
8: '2', terminal
9: '3', terminal
10: '4', terminal
11: '5', terminal
12: '6', terminal
13: '7', terminal
14: '8', terminal
15: '9', terminal} ],

[ 'tokens', q{'-': -
'1': 1
'2': 2
'3': 3
'4': 4
'.': .
'4': 4
'2': 2
'3': 3} ],

[ 'terminals', q{'-'
'.'
'0'
'1'
'2'
'3'
'4'
'5'
'6'
'7'
'8'
'9'} ],

[ 'bnf_tokens', q{identifier: expr
::=: ::=
literal: '-'
identifier: num
|: |
identifier: num
identifier: num
::=: ::=
identifier: digits
|: |
identifier: digits
literal: '.'
identifier: digits
identifier: digits
::=: ::=
identifier: digit
|: |
identifier: digit
identifier: digits
identifier: digit
::=: ::=
literal: '0'
|: |
literal: '1'
|: |
literal: '2'
|: |
literal: '3'
|: |
literal: '4'
|: |
literal: '5'
|: |
literal: '6'
|: |
literal: '7'
|: |
literal: '8'
|: |
literal: '9'} ],

[ 'bnf_rules', q{0: expr -> '-' num
1: expr -> num
2: num -> digits
3: num -> digits '.' digits
4: digits -> digit
5: digits -> digit digits
6: digit -> '0'
7: digit -> '1'
8: digit -> '2'
9: digit -> '3'
10: digit -> '4'
11: digit -> '5'
12: digit -> '6'
13: digit -> '7'
14: digit -> '8'
15: digit -> '9'} ],

[ 'rules', q{0: expr -> '-' num
1: expr -> num
2: num -> digits
3: num -> digits '.' digits
4: digits -> digit
5: digits -> digit digits
6: digit -> '0'
7: digit -> '1'
8: digit -> '2'
9: digit -> '3'
10: digit -> '4'
11: digit -> '5'
12: digit -> '6'
13: digit -> '7'
14: digit -> '8'
15: digit -> '9'} ],

[ 'literals', q{'-'
'.'
'0'
'1'
'2'
'3'
'4'
'5'
'6'
'7'
'8'
'9'} ],

[ 'lexer_regexes', q{(?^:0): "'0'"
(?^:1): "'1'"
(?^:2): "'2'"
(?^:3): "'3'"
(?^:4): "'4'"
(?^:5): "'5'"
(?^:6): "'6'"
(?^:7): "'7'"
(?^:8): "'8'"
(?^:9): "'9'"
(?^:\\-): "'-'"
(?^:\\.): "'.'"} ],

[ 'bnf_tokens', q{identifier: expr
::=: ::=
literal: '-'
identifier: num
|: |
identifier: num
identifier: num
::=: ::=
identifier: digits
|: |
identifier: digits
literal: '.'
identifier: digits
identifier: digits
::=: ::=
identifier: digit
|: |
identifier: digit
identifier: digits
identifier: digit
::=: ::=
literal: '0'
|: |
literal: '1'
|: |
literal: '2'
|: |
literal: '3'
|: |
literal: '4'
|: |
literal: '5'
|: |
literal: '6'
|: |
literal: '7'
|: |
literal: '8'
|: |
literal: '9'} ],

[ 'lexer_rules', q{-: '-'
.: '.'
0: '0'
1: '1'
2: '2'
3: '3'
4: '4'
5: '5'
6: '6'
7: '7'
8: '8'
9: '9'} ]

    ){
    # get data
    my ($option_name, $expected) = @$data;
    
    my $option  = "show_$option_name";

    # set up the grammar
    my $mp = Marpa::Easy->new({
        rules => $grammar,
        default_action => 'AoA',
        $option => 1
    });
    
    # set up comment
    my $comment = $mp->comment_option( $option_name );

    # test
    stdout_is { $mp->parse($number) } "$comment\n$expected\n", "diagnostic printed by setting $option => 1 in the constructor";
    is $mp->$option, $expected, "diagnostic returned by calling $option directly";
}

done_testing;
