package MarpaX::Parse::Grammar;

use 5.010;
use strict;
use warnings;

use Carp qw{cluck};
use YAML;

use Marpa::R2;

use Math::Combinatorics;

sub new{

    my $class = shift;
    my $options = shift;
  
    my $self = {};
    bless $self, $class;
    
    return $self;

}


1;

