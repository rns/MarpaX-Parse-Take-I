package MarpaX::Parse::Grammar::EBNF;

use 5.010;
use strict;
use warnings;

use YAML;

use Eval::Closure;
use Clone qw {clone};

use MarpaX::Parse::Grammar::EBNF::Parser;

our @ISA = qw(MarpaX::Parse::Grammar);

sub new {

    my $class = shift;

    my $options = shift;
    
#    say Dump $options;

    # get ebnf text
    my $ebnf_text = $options->{rules};

    # parse bnf (generate closures as { action => closure } in rule hashref
    my $ebnf_parser = MarpaX::Parse::Grammar::EBNF::Parser->new;
    $options->{rules} = $ebnf_parser->parse($ebnf_text);

#    say Dump $options;

    # TODO: save $ebnf_text rules and $options->{rules} for merging
    
    # build Marpa::R2 grammar
    my $self = $class->SUPER::new( $options );

    bless $self, $class;
}

1;
