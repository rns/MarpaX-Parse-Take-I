use 5.010;
use strict;
use warnings;

package MarpaX::Parse;

use YAML;

use Marpa::R2;

use MarpaX::Parse::Grammar;
use MarpaX::Parse::Grammar::BNF;
use MarpaX::Parse::Grammar::EBNF;

#
# Any BNF grammar passed to MarpaX::Parse by setting <rules> to scalar 
# is parsed by the BNF parser with rules set in MarpaX::Parse::BNF
#
# BNF parser tokens, rules and closures are shown by show_bnf_parser_* options
# 
# tokens, rules and closures of the BNF grammar passed to MarpaX::Parse are shown
# by show_bnf_* options
# 
# Finally, tokens, rules and closures of the input parsed by the BNF grammar passed 
# to MarpaX::Parse are shown # by show_* options
#

sub new{

    my $class = shift;
    my $options = shift;
    
    my $self = {};
    
    # TODO: extract recognizer options and pass them to parser
    my @recognizer_options = qw{
        closures
        end
        event_if_expected
        max_parses
        ranking_method
        too_many_earley_items
        trace_actions
        trace_file_handle
        trace_terminals
        trace_values
        warnings
    };

    my $grammar;
    # array ref means we have rules
    if (ref $options->{rules} eq "ARRAY"){  
        # set up and save the grammar
        $grammar = MarpaX::Parse::Grammar->new($options);
    }
    # scalar means we have a BNF or EBNF grammar we need to parse to get rules
    elsif (ref $options->{rules} eq ""){
        # try bnf first
        # backup rules
        my $rules = $options->{rules};
        eval {
            $grammar = MarpaX::Parse::Grammar::BNF->new($options);
        };
        # now try EBNF
        if ($@){
            my $bnf_parsing_errors = $@;
            # TODO: catch EBNF parsing errors, e.g. := not ::=

            # restore rules after Marpa::R2 creation attempt
            $options->{rules} = $rules;
            eval {
                $grammar = MarpaX::Parse::Grammar::EBNF->new($options);
            };
            if ($@){
                # TODO: return parsing errors somehow 
                my $ebnf_parsing_errors = $@;
                $@ = "\n# bnf parsing error(s)\n"  .  $bnf_parsing_errors . 
                     "# ebnf parsing error(s)\n" . $ebnf_parsing_errors;
                return;
            }
        }
    }
    # everything else
    else {
        die "Don't know what to do with rules in these options:", Dump $options;
    }
    
    # save grammar
    $self->{g} = $grammar;

    # set up parser
    $self->{p} = MarpaX::Parse::Parser->new( $grammar );
    
    bless $self, $class;
}

# =========
# accessors
# =========

sub grammar { $_[0]->{g}->grammar }

sub parse {

    my $self = shift;
    
    my $input = shift;

    return $self->{p}->parse($input);
}

1;

__END__
