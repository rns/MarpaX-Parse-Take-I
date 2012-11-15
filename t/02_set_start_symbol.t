use 5.010;
use strict;
use warnings;

use Test::More tests => 2;

use_ok 'MarpaX::Parse::Grammar';

# The below is BNF for decimal numbers, no literals
#
#    expr    ::= - num | num 
#    num     ::= digits | digits . digits 
#    digits  ::= digit | digits digit
#    digit   ::= 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9

# set up the grammar
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

sub do_what_I_mean { 
    shift;
    my @values = grep { defined } @_;
    scalar @values > 1 ? \@values : shift @values;
}

my $g = MarpaX::Parse::Grammar->new({ 
    rules => $rules,
    default_action => __PACKAGE__ . '::do_what_I_mean',
});

# set up test data
my $number = [
    [ '1', '1' ],
    [ '2', '2' ],
    [ '3', '3' ],
    [ '4', '4' ],
];

# setup the recognizer
my $recognizer = Marpa::R2::Recognizer->new( { 
    grammar => $g->grammar, 
} ) or die 'Failed to create recognizer';

# read tokens
for my $token (@$number){
    defined $recognizer->read( @$token ) or die "Recognition failed";
}

#
# The Dumper
#
use Data::Dumper;

$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;

# evaluate the parse
while ( defined( my $value_ref = $recognizer->value() ) ) {
    my $value = $value_ref ? ${$value_ref} : 'No parse';
    is Dumper($value), "[[['1','2'],'3'],'4']", "decimal number recognized with start symbol set by the tool";
}


