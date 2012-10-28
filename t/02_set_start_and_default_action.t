use 5.010;
use strict;
use warnings;

use YAML;
use Test::More tests => 3;

use_ok 'Marpa::Easy';

my $rules = [

    [ expr => [qw(- num)] ],
    [ expr => [qw(num)] ],

    [ num => [qw(digits)] ],
    [ num => [qw(digits . digits)] ],

    [ digits => [qw(digit)] ],
    [ digits => [qw(digits digit)] ],

    [ digit => [qw(0)] ],
    [ digit => [qw(1)] ], 
    [ digit => [qw(2)] ], 
    [ digit => [qw(3)] ], 
    [ digit => [qw(4)] ], 
    [ digit => [qw(5)] ], 
    [ digit => [qw(6)] ], 
    [ digit => [qw(7)] ], 
    [ digit => [qw(8)] ], 
    [ digit => [qw(9)] ],

];

my $m = Marpa::Easy->new({ 
    rules => $rules,
    default_action => 'AoA_with_rule_signatures',
});

my $number = [
    [ '1', '1' ],
    [ '2', '2' ],
    [ '3', '3' ],
    [ '4', '4' ],
];

my $value;

$value = $m->parse($number);
#say Dump $value;

is_deeply $value, Load(<<END_OF_PARSE), "numeral parsed with start symbol and default action AoA_with_rule_signatures";
---
- expr -> num
-
  - num -> digits
  -
    - digits -> digits digit
    -
      -
        - digits -> digits digit
        -
          -
            - digits -> digits digit
            -
              -
                - digits -> digit
                -
                  - digit -> 1
                  - 1
              -
                - digit -> 2
                - 2
          -
            - digit -> 3
            - 3
      -
        - digit -> 4
        - 4
END_OF_PARSE

my $m1 = Marpa::Easy->new({ rules => $rules, default_action => 'AoA' });
$value = $m1->parse($number);

is_deeply $value, Load(<<END_OF_PARSE), "numeral parsed with start symbol set automagically and default action AoA specified";
---
-
  -
    - 1
    - 2
  - 3
- 4
END_OF_PARSE

#
# TODO: more default actions: HoA AoH
#
