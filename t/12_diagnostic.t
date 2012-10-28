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
    default_action => 'AoA',
});

# input
my $number = '-1234.423'; 

# parse
my $AoA = $bnf->parse($number);
#say Dump $AoA;

# show

stdout_is { say "# BNF tokens:\n", $bnf->show_bnf_tokens } <<EOT, "BNF tokens shown";
# BNF tokens:
identifier: expr
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
literal: '9'
EOT

stdout_is { say "# BNF rules:\n", $bnf->show_bnf_rules } <<EOT, "BNF rules shown";
# BNF rules:
0: expr -> '-' num
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
15: digit -> '9'
EOT

stdout_is { say "# rules:\n", $bnf->show_rules } <<EOT, "rules shown";
# rules:
0: expr -> '-' num
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
15: digit -> '9'
EOT

stdout_is { say "# symbols:\n", $bnf->show_symbols } <<EOT, "symbols shown";
# symbols:
0: expr
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
15: '9', terminal
EOT

stdout_is { say "# tokens:\n", $bnf->show_tokens } <<EOT, "tokens shown";
# tokens:
'-': -
'1': 1
'2': 2
'3': 3
'4': 4
'.': .
'4': 4
'2': 2
'3': 3
EOT

stdout_is { say "# terminals:\n", $bnf->show_terminals } <<EOT, "terminals shown";
# terminals:
'-'
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
'9'
EOT

stdout_is { say "# literals:\n", $bnf->show_literals } <<EOT, "literals shown";
# literals:
'-'
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
'9'
EOT

stdout_is { say "# lexer rules:\n", $bnf->show_lexer_rules } <<EOT, "lexer rules shown";
# lexer rules:
-: '-'
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
9: '9'
EOT

stdout_is { say "# lexer regexes:\n", $bnf->show_lexer_regexes } <<EOT, "lexer regexes shown";
# lexer regexes:
---
(?^:0): "'0'"
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
(?^:\\.): "'.'"
EOT

#diag "# recognition_failures:\n",   $bnf->show_recognition_failures;
done_testing;
