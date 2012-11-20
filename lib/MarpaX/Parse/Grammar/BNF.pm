package MarpaX::Parse::Grammar::BNF;

use 5.010;
use strict;
use warnings;

use YAML;

use Clone qw{clone};

use MarpaX::Parse::Grammar::BNF::Parser;

our @ISA = qw(MarpaX::Parse::Grammar);

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

    say "merging $token_rules";

    # get initial options
    my $options = $self->{options};

    say ref $self;
    say ref $token_rules;
    say ref $options->{rules};
    
    # $token_rules and $options->{rules} need to be both texts
    if (ref $token_rules eq "" and ref $options->{rules} eq ""){
        # merge texts
        say "merging $token_rules with $options->{rules}";
        $options->{rules} .= $token_rules;
    }
    
    # rebuild
    $self->build($options);
}

sub rules { $_[0]->{rules} }

1;
