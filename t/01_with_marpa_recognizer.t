use 5.010;
use strict;
use warnings;

use YAML;
use Test::More tests => 2;

use MarpaX::Parse;

# this is needed to test that only anonymous subs are extracted
# and action names are left as is
sub do_minus_num { }

my $rules = [

    [ expr => [qw(- num)], do_minus_num ],
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

    # The first argument is the per-parse variable.
    # At this stage, just throw it away
    shift;

    # Throw away any undef's
    my @children = grep { defined } @_;
    
    # Return what's left as an array ref or a scalar
    scalar @children > 1 ? \@children : shift @children;
}

my $me = MarpaX::Parse->new({
    start => 'expr',
    rules => $rules,
    default_action => __PACKAGE__ . '::do_what_I_mean',
});

my $number = [
    [ '1', '1' ],
    [ '2', '2' ],
    [ '3', '3' ],
    [ '4', '4' ],
];

# setup recognizer
my $recognizer =
    Marpa::R2::Recognizer->new( { 
        grammar => $me->grammar, 
    } );
die 'Failed to create recognizer' if not $recognizer;

# read tokens
for my $digit (@$number){
    defined $recognizer->read( @$digit ) or say "Recognition failed at ", $digit->[0];
}

# evaluate
my $value;
while ( defined( my $value_ref = $recognizer->value() ) ) {
    $value = $value_ref ? ${$value_ref} : 'No parse';
}

is_deeply $value, Load(<<END_OF_PARSE), "decimal integer parsed with MarpaX::Parse and Marpa::R2::Recognizer";
---
-
  -
    - 1
    - 2
  - 3
- 4
END_OF_PARSE

#
# The same can be done with parse method of MarpaX::Parse.
# The default action AoA (array of arrays) will be set by MarpaX::Parse.
#
my $me_AoA = MarpaX::Parse->new({
    rules => $rules
});

$value = $me_AoA->parse($number);

is_deeply $value, Load(<<END_OF_PARSE), "decimal integer parsed with MarpaX::Parse::parse";
---
-
  -
    - 1
    - 2
  - 3
- 4
END_OF_PARSE
