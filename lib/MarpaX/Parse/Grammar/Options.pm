package MarpaX::Parse::Grammar::Options;

use 5.010;
use strict;
use warnings;

sub new{

    my $class = shift;
    my $grammar = shift;
  
    my $self = {};
    bless $self, $class;
    $self->{grammar} = $grammar;
    $self;
}

1;

