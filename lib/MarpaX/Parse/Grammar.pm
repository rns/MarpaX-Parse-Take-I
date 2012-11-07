package MarpaX::Parse::Grammar;

use 5.010;
use strict;
use warnings;

use Carp qw{cluck};
use YAML;

use Marpa::R2;

use Math::Combinatorics;

use Clone qw(clone);

my $MarpaX_Parse_Grammar_options = {

    # transform quantified symbols into sequence (by default) or recursive rules
    quantifier_rules => undef,

    # if true, nullable symbols will be added instead removing the rules 
    # with ?/*-quanfitied symbols
    nullables_for_quantifiers => undef,
    
};

sub new{

    my $class = shift;
    my $options = shift;
  
    my $self = {};
    bless $self, $class;

    # clone options to enable adding rules to grammar
    $self->{options} = clone $options;
    
    # extract MarpaX::Parse::Grammar options and set defaults
    while (my ($option, $value) = each %$options){
        if (exists $MarpaX_Parse_Grammar_options->{$option}){
            $self->{$option} = $value;
            delete $options->{$option};
        }
    }
    # set defaults
    $self->{quantifier_rules}               //= 'sequence';
    
    return $self;
}

sub _rule_signature
{
    my ($lhs, $rhs) = @_;
    return "$lhs -> " . join ' ', @$rhs;
}

sub _action_name
{
    return "action(" . _rule_signature(@_) . ")";
}

sub _extract_start_symbol
{
    my $self = shift;
    
    my $rules = shift;
    
    my $rule0 = $rules->[0];
    
    my $start = ref $rule0 eq "HASH" ? $rule0->{lhs} : $rule0->[0];
    $self->{start} = $start;
    
    return $start;
}

sub _closures_to_actions
{
    my $self = shift;
    
    my $rules = shift;
    
#    say "# _closures_to_actions: rules:\n", Dump $rules;
    
    my $closures = {};
    
    for my $rule (@$rules){
        my ($lhs, $rhs, $closure);
        given (ref $rule){
            when ("HASH"){
                # get the rule's parts
                $lhs = $rule->{lhs};
                $rhs = $rule->{rhs};
                $closure = $rule->{action};
                # we need anonymous subs and not the action names
                if (defined $closure and ref $closure eq "CODE"){
                    # make action name
                    my $an = _action_name($lhs, $rhs);
                    # replace closure with action name
                    $closures->{$an} = $closure;
                    # add closure for recognizer
                    $rule->{action}  = $an;
                }
            }
            when ("ARRAY"){
                # get the rule's parts
                ($lhs, $rhs, $closure) = @$rule;
                # we need anonymous subs and not the action names
                if (defined $closure  and ref $closure eq "CODE"){
                    # make action name
                    my $an = _action_name($lhs, $rhs);
                    # replace closure with action name
                    $rule->[-1]      = $an;
                    # add closure for recognizer
                    $closures->{$an} = $closure;
                }
            }
        }
        
    }
    
#    say "# _closures_to_actions: closures:\n", Dump $closures;
    
    return $closures;
}

=head2
    
    For each symbol ending with * or + add a Marpa sequence rule 
    with lhs being the symbol, rhs being symbols without the quantifier 
    the min => 0 or min => 1, respectively
    
    For each symbol ending with ?, add a new rule without such symbol
    and remove ? from the symbol's end. 
    
    Several symbols may be zero (? *)-quantified and all needed rules will be added.
    
=cut

sub _quantifiers_to_rules
{   
    my $self = shift;
    
    my $rules = shift;
    
#    say "# rules ", Dump $rules;
    
    # symbols quantified with * or + require adding sequence rules
    my $quantified_symbol_rules = [];

    # symbols quantified with * or ? require adding rules without such symbols
    # more than one symbol per rules can be  * or ? quantified hence 
    # $nullable_symbol_indices->{quantified_rule_index}->{nullable_symbol_index}
    my $nullable_symbol_indices = {};
    
    # prevent duplication of sequence rules' lhs 
    my $sequence_lhs = {}; 

    # process rules
    for my $j (0..@$rules-1){
        my $rule = $rules->[$j];
#        say "# rule ", Dump $rule;
        # get lhs and rhs
        my ($lhs, $rhs);
        given (ref $rule){
            when ("HASH"){
                $lhs = $rule->{lhs};
                $rhs = $rule->{rhs};
            }
            when ("ARRAY"){
                ($lhs, $rhs) = @$rule;
            }
        }
#        say "# $lhs -> ", Dump $rhs;
        # check symbols ending with quantifiers
        for my $i (0..@$rhs-1){
            my $symbol = $rhs->[$i];
            # TODO: better checking for regexes (\d+)
            if ($symbol =~ m/(\?|\*|\+)$/ and $symbol !~ m{\\}){
                my $quantifier = $1;
#                say "$quantifier, $rhs->[$i]";
                # setup sequence item ($symbol without quantifier)
                my $non_quantified_symbol = $symbol;
                $non_quantified_symbol =~ s/\Q$quantifier\E$//;
#                say "$quantifier, $rhs->[$i], $symbol";
                # dispatch on quantifier
                given ($quantifier){
                    when ("?"){
#                        say "# zero or one ", Dump $rule;
                        # set rule's nullable symbol indices
                        $nullable_symbol_indices->{$j}->{$i} = undef;
                        # replace quantified symbol to non-quantified in the rule
                        $rhs->[$i] = $non_quantified_symbol;
                    }
                    # add min => 0 or min => 1 sequence 
                    when ([qw(* +)]){
                        
                        # sequence lhs must be unique
                        unless (exists $sequence_lhs->{$symbol} ){
                            if ($self->{quantifier_rules} eq 'recursive'){
#                                say "sequences as recursive rules";
                                my $item = $non_quantified_symbol;
                                my $seq = $symbol;
                                # seq ::= item
                                push @$quantified_symbol_rules, { 
                                    lhs     => $seq,
                                    rhs     => [ $item ],
                                    action  => sub { 
                                        [ $_[1] ];
                                    },
                                };
                                # seq ::= item seq
                                push @$quantified_symbol_rules, { 
                                    lhs     => $seq,
                                    rhs     => [ $seq, $item ],
                                    action  => sub { 
                                        if (ref $_[1] eq "" and ref $_[2] eq ""){
                                            return ($_[1] ? $_[1] : '') . ($_[2] ? $_[2] : '');
                                        }
                                        else{
                                            push @{ $_[1] }, $_[2];
                                        }
                                        return $_[1];
                                    },
                                };
                            }
                            else{
#                                say "sequences as sequence rules";
                                push @$quantified_symbol_rules, { 
                                    lhs => $symbol,
                                    rhs => [ $non_quantified_symbol ],
                                    min => $quantifier eq '+' ? 1 : 0,
#                                    action => sub { 
                                        # strip per-parse variable
#                                        shift;
    #                                    say Dump \@_;
    #                                    say defined @_;
    #                                    say join '', @_;
                                        # return empty array ref rather than undef for null (zero-item) sequences
#                                        \@_;
#                                    },
                                };
                            }
                            $sequence_lhs->{$symbol} = undef;
                        }
                        # set rule's nullable symbol indices
                        if ($quantifier eq '*'){
                            $nullable_symbol_indices->{$j}->{$i} = undef;
                        }
                    }
                }
            }
        }
    }
    
    # add rules for quantified symbols
#    say Dump $quantified_symbol_rules;
    push @$rules, @$quantified_symbol_rules;

    # just add [ nullable_symbol => [] ] rules if the options are set
    if ($self->{nullables_for_quantifiers}){
        my @nullables;
        my %nullables;
        for my $j (keys %$nullable_symbol_indices){
            my $rule = $rules->[$j];

            my ($lhs, $rhs);
            given (ref $rule){
                when ("HASH"){
                    $lhs = $rule->{lhs};
                    $rhs = $rule->{rhs};
                }
                when ("ARRAY"){
                    ($lhs, $rhs) = @$rule;
                }
            }

            my @nullables = sort keys %{ $nullable_symbol_indices->{$j} };
            for my $nullable (@nullables){
#                say $rhs->[$nullable];
                # avoid tule duplication
                next if exists $nullables{ $rhs->[$nullable] };
                push @$rules, [ $rhs->[$nullable] => [] ];
                $nullables{ $rhs->[$nullable] } = undef;
            }
        }
    }
    else {
        # generate and add rules with nullable symbols
        my @rules_with_nullables;
        for my $j (keys %$nullable_symbol_indices){
            my $rule = $rules->[$j];

            my ($lhs, $rhs);
            given (ref $rule){
                when ("HASH"){
                    $lhs = $rule->{lhs};
                    $rhs = $rule->{rhs};
                }
                when ("ARRAY"){
                    ($lhs, $rhs) = @$rule;
                }
            }

            my @nullables = sort keys %{ $nullable_symbol_indices->{$j} };
            # generate the indices of symbols to null
    #        say "$lhs -> @$rhs\nnullables:@nullables";
            my @symbols_to_null;
            for my $k (1..@nullables){
                my @combinations = combine($k, @nullables);
                push @symbols_to_null, \@combinations;
    #            say "$k:", join ' | ', map { join ' ', @$_ } @combinations;
            }
            # generate nullables rhs by deleting nullable symbols according to generated indices
            for my $combinations (@symbols_to_null){
                # delete (null) nullable symbols
                for my $combination (@$combinations){
    #                say "@$combination";
                    my @nullable_rhs = @$rhs;
                    for my $index (@$combination){
                        $nullable_rhs[$index] = undef;
                    }
                    @nullable_rhs = grep {defined} @nullable_rhs;
    #                say "$lhs -> @nullable_rhs";
                    push @rules_with_nullables, { lhs => $lhs, rhs => \@nullable_rhs };
                }
            }
        }
    #    say Dump \@rules_with_nullables;
        push @$rules, @rules_with_nullables;
    }
    
}

sub _extract_terminals
{
    my $self = shift;
    
    my $rules = shift;
    my $grammar = shift;
    
    my $symbols = $self->_extract_symbols($rules);
    
    my $terminals = [];
    for my $symbol (keys %$symbols){
        if ($grammar->check_terminal($symbol)){
            push @$terminals, $symbol;
        }
    }
    $self->{terminals} = $terminals;
    
    return $terminals;
}

sub _extract_symbols
{
    my $self = shift;
    
    my $rules = shift;
    
    my $symbols = {};
    
    for my $rule (@$rules){
        my ($lhs, $rhs);
        given (ref $rule){
            when ("HASH"){
                # get the rule's parts
                $lhs = $rule->{lhs};
                $rhs = $rule->{rhs};
            }
            when ("ARRAY"){
                # get the rule's parts
                ($lhs, $rhs) = @$rule;
            }
        }
        for my $symbol ($lhs, @$rhs){
            $symbols->{$symbol} = undef;
        }
    }
    $self->{symbols} = $symbols;
    
    return $symbols;
}

# lexer rules are derived from literal terminals, which can be 
# strings or qr// patterns in single or double quotes
sub _extract_lexer_rules
{
    my $self = shift;
    
    my $rules = shift;

    # TODO: _extract_terminals needs to be called rather than using terminals
    my $terminals = $self->{terminals};
    
#    $self->show_option('rules');
#    $self->show_option('symbols');
#    $self->show_option('terminals');

    my $lr = {};

    # lexer rules are formed by terminals wrapped in single or double quotes
    my @literals;
    for my $terminal (@$terminals){
#        say "# terminal:\n", $terminal;
        if (
            (substr($terminal, 0, 1) eq '"' and substr($terminal, -1) eq '"') or
            (substr($terminal, 0, 1) eq "'" and substr($terminal, -1) eq "'")
            ){
            push @literals, $terminal;
            my $literal = substr $terminal, 1, -1;
#            say "# lexer rule: <$literal> -> <$terminal>";
            $lr->{$literal} = $terminal;
        }
    }
    # save and show literals if show_literals is set
#    $self->set_option('literals', join "\n", sort @literals );
#    $self->show_option('literals');
    $self->{lexer_rules} = $lr;
    return $lr;
}

1;

