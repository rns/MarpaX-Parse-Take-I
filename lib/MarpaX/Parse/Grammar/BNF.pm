package MarpaX::Parse::Grammar::BNF;

use 5.010;
use strict;
use warnings;

use YAML;

use MarpaX::Parse::Grammar::BNF::Parser;

use parent 'MarpaX::Parse::Grammar';

# construction
sub new
{
    my $class = shift;
    
    my $options = shift;
    
#    say Dump $options;

    # get bnf text
    my $bnf_text = $options->{rules};
    
    # parse bnf (generate closures as { action => closure } in rule hashref
    my $bnf_parser = MarpaX::Parse::Grammar::BNF::Parser->new;
    $options->{rules} = $bnf_parser->parse($bnf_text);

#    say Dump $options;

    # TODO: save $bnf_text rules and $options->{rules} for merging
    
    # build Marpa::R2 grammar
    my $self = $class->SUPER::new( $options );

    bless $self, $class;
}

sub merge_token_rules { 
    
    my $self = shift;

    my $token_rules = shift;

#    say "# BNF: merging $token_rules";

    # get initial options
    my $options = $self->{options};

#    say ref $self;
#    say ref $token_rules;
#    say ref $options->{rules};
#    say Dump $options->{rules};
    
    if (ref $token_rules eq ""){
        push @{ $options->{rules} }, @{ MarpaX::Parse::Grammar::BNF::Parser->new->parse($token_rules) };
    }
    
#    say "# added token rules:\n", Dump $options->{rules};
    
    # rebuild
    $self->build($options);
    
#    say "# rebuilt:\n", $self->grammar->show_rules;
}

sub rules { $_[0]->{rules} }

1;
