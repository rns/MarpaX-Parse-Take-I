use 5.010;
use strict;
use warnings;

use YAML;
use Test::More tests => 4;

use Marpa::Easy;

# The below is BNF for decimal numbers with literals
#
#    expr    ::= '-' num | num 
#    num     ::= digits | digits '.' digits 
#    digits  ::= digit | digits digit
#    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'

my $m = Marpa::Easy->new({   
    start   => 'expr',
    rules   => [
        [ expr => [qw('-' num)], sub { $_[1] . $_[2] } ],
        [ expr => [qw(num)],     sub { $_[1] } ],

        [ num => [qw(digits)], 
          sub {
            join( '', @{ $_[1] } )
          }
        ],
        [ num => [qw(digits '.' digits)], 
          sub {
            join( '', @{ $_[1] } ) . $_[2] . join( '', @{ $_[3] } )
          }
        ],

        [ digits => [qw(digit)], 
          sub { 
            [ $_[1] ]                           # setup the sequence
        } ],
        [ digits => [qw(digits digit)], 
          sub { 
            push @{$_[1]}, $_[2];               # add next item to the sequence
            $_[1]                               # return the sequence array ref
        } ],

        [ digit => [qw('0')], sub { $_[1] } ],
        [ digit => [qw('1')], sub { $_[1] } ], 
        [ digit => [qw('2')], sub { $_[1] } ], 
        [ digit => [qw('3')], sub { $_[1] } ], 
        [ digit => [qw('4')], sub { $_[1] } ], 
        [ digit => [qw('5')], sub { $_[1] } ], 
        [ digit => [qw('6')], sub { $_[1] } ], 
        [ digit => [qw('7')], sub { $_[1] } ], 
        [ digit => [qw('8')], sub { $_[1] } ], 
        [ digit => [qw('9')], sub { $_[1] } ],
    ]
});

my $numbers = [
    '1234',
    '-1234.423',
    '-123',
    '1234.43',
];

for my $number (@$numbers){
    my $value = $m->parse($number);
    is $value, $number, "decimal number $number lexed on digits and parsed with closures in rules";
}




