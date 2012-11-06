use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'MarpaX::Parse';

use Eval::Closure;

my $ebnf_in_bnf = q{

  grammar       ::= production+
        %{
            shift;
#            { grammar => $_[0] };
            return [ map { @$_ } @{ $_[0] } ];
        %}
  
  production    ::= lhs '::=' rhs action?
        %{
            my $per_parse = shift;
            
            my @value = grep { defined } @_;
            
            # Marpa rules-to-be
            my $rules = [];
            my $closures = {};
            
            # set up Marpa::R2 rules
            my ($lhs, undef, $rhs, $production_action) = @value;
            say "# production/lhs:\n$lhs";
            say "# production/rhs:\n", Dump $rhs;

            # extract production action, if any
            if (ref $production_action eq "HASH" and exists $production_action->{action}){
                $production_action = $production_action->{action};
                say "production_action: $production_action";
            }

            sub make_rule{
                my ($lhs, $rhs, $lhs_action) = @_;
                
                my $rule = [];
                my $subrule_closures = {};
                my $alt = $rhs->{alternation};
                $lhs_action = $rhs->{action};
                for my $seq ( map { $_->{sequence} } @{ $alt } ){
            #                say "# seq:\n", Dump $seq;
                    my @rhs;
                    my $closure;
                    for my $item (@$seq){
                        if (exists $item->{symbol}){
                            push @rhs, $item->{symbol};
                            # extract and set up action, if any
                            if (exists $item->{action}){
                                # set up closure
                                $closure = $item->{action};
                                $subrule_closures->{$item->{symbol}} = $closure;
                                say "\t\t$closure";
                            }
                        }
                        elsif (exists $item->{subrule}){
                            push @rhs, $item->{subrule} =~ /^__/ ? $lhs . $item->{subrule} : $item->{subrule};
                        }
                        else{
#                            say '# something else: ', Dump $item;
                        }
                    }
                    say "$lhs -> @rhs", $lhs_action ? "\t$lhs_action" : '';
                    # add rule
                    push @$rule, { lhs => $lhs, rhs => \@rhs };
                    # add action to rule
                    if ($lhs_action){
                        # set up closure
                        
                        # add closure to rule
                        
                    }
                }            
                return ($rule, $subrule_closures);
            }
            
            my ($rule, $subrule_closures) = make_rule($lhs, $rhs, $production_action);
            # add rule
            push @$rules, @$rule;
            # add $%rule_clocures to %$closures to be added to the respective rules
            # after they are set up
            say "# subrule closures to be added:\n", Dump $subrule_closures;
            $closures->{$_} = $subrule_closures->{$_} for keys %$subrule_closures;
            
            # add subrules, if any
            if ( exists $per_parse->{subrules} and defined $per_parse->{subrules} ){
                say "# subrules:\n", Dump $per_parse->{subrules};
                for my $subrule_lhs (keys %{ $per_parse->{subrules} }){
                    my ($rule, $subrule_closures) = make_rule(
                        $subrule_lhs =~ /^__/ ? $lhs . $subrule_lhs : $subrule_lhs, 
                        $per_parse->{subrules}->{$subrule_lhs}
                    );
                    # add rule
                    push @$rules, @$rule;
                    # add $%rule_clocures to %$closures to be added to the respective rules
                    # after they are set up
#                    say "closures to be added", Dump $subrule_closures;
                    $closures->{$_} = $subrule_closures->{$_} for keys %$subrule_closures;
                }
                # reinitialize subrules (expressions in parens)
                $per_parse->{subrules}      = ();
                $per_parse->{subrule_id}    = 0;
            }
            
            say Dump $rules;
            # add closures to the rules, whose rhs contains the symbol
            for my $symbol (keys %$closures){
                say "# subrule closure to be added:\n", $symbol, ' -> ', $closures->{$symbol};
            }            
            
#            \@_;
            return $rules
        %}

  lhs ::= symbol

  rhs ::= 

    term action?
        %{ 
            shift;

#            say "# $rule_signature:\n", Dump \@_;

            my @value = grep { defined } @_;
            my $term = { alternation => [ shift @value ] };
            push @{ $term->{alternation}->[0]->{sequence} }, $value[0] if ref $value[0] eq "HASH" and exists $value[0]->{action};
            
#            say "# $rule_signature (value):\n", Dump $term;
            
            $term;
        %}
        |

    term action? '|' rhs
        %{ 
            shift;
#            say "# $rule_signature:\n", Dump \@_;
            
            my @value = grep { defined } @_;
            
            # extract and set up the term
            my $term = shift @value;
            # extract rhs
            my $rhs = pop @value;
            # extract '|';
            pop @value;
            # extract action, if any
            $term->{action} = $value[0]->{action} if ref $value[0] eq "HASH" and exists $value[0]->{action};
            # prepend term to rhs
            unshift @{ $rhs->{alternation} }, $term; 
            
#            say "# $rule_signature (value):\n", Dump $rhs;
            
            $rhs
        %}

  term ::= 
    
    factor
        %{ 
            shift;
#            say "# $rule_signature:\n", Dump \@_;
            { sequence => [ $_[0] ] } 
        %}
        |
    term factor
        %{ 
            shift;
#            say "# $rule_signature:\n", Dump \@_;
            push @{ $_[0]->{sequence} }, $_[1]; 
            $_[0]
        %}
    
  action        ::= 'qr/%{.+?%}/'
        %{ 
            { action => $_[1] }
        %}
        
  factor        ::= 

# symbols can have actions only if they are non-terminals
    symbol quantifier? # action?
        %{ 
            shift;

            my @value = grep { defined } @_;
#            say "# $rule_signature:\n", Dump \@value;
#            return @value > 1 ? \@value : shift @value;
            
            # extract quantifier and action
            my @quantifier = map { $_->{quantifier} } grep { ref eq "HASH" and exists $_->{quantifier} } @value;
#            my @action     = map { $_->{action}      } grep { ref eq "HASH" and exists $_->{action} } @value;

            # set up factor
            my $factor = { symbol => $value[0] };

            # add quantifier and action, if any, to the factor
#            $factor->{action}  = shift @action if @action;
            $factor->{symbol} .= shift @quantifier if @quantifier;

            # return factor
            $factor;
        %} 
        |
# symbols can have actions only if they are non-terminals
# subexpressions are, so they can
    '(' rhs ')' quantifier? action?
        %{ 
            my $per_parse = shift; # per-parse var

            my @value = grep { defined } @_;
#            say "# $rule_signature:\n", Dump \@value;
#            return @value > 1 ? \@value : shift @value;
            
            # extract quantifier and action
            my @quantifier = map { $_->{quantifier} } grep { ref $_ eq "HASH" and exists $_->{quantifier} } @value;
            my @action     = map { $_->{action}      } grep { ref $_ eq "HASH" and exists $_->{action} } @value;

            # init subrule with counted lhs
            my $subrule_id  = $per_parse->{subrule_id} || 0;
            my $subrule_lhs = "__subrule" . $subrule_id++;

            # add action, if any, to the subrule
            $value[1]->{action}   = shift @action if @action;
            # save subrule and its id
            $per_parse->{subrules}->{$subrule_lhs} = $value[1];
            $per_parse->{subrule_id}               = $subrule_id;
            
            # set up factor as the subrule's lhs rather than the subrule's contents
            my $factor = { subrule => $subrule_lhs };

            # add quantifier, if any, to the subrule's lhs (not $per_parse->{subrules}
            $factor->{subrule} .= shift @quantifier if @quantifier;

            # return factor
            $factor;
        %}
        |
# symbols can have actions only if they are non-terminals
# named subexpressions are, so they can
    '(' identifier ':' rhs ')' quantifier? action?
        %{ 
            my $per_parse = shift; # per-parse var

            my @value = grep { defined } @_;
#            say "# $rule_signature:\n", Dump \@value;
#            return @value > 1 ? \@value : shift @value;
            
            # extract quantifier and action
            my @quantifier = map { $_->{quantifier} } grep { ref eq "HASH" and exists $_->{quantifier} } @value;
            my @action     = map { $_->{action}      } grep { ref eq "HASH" and exists $_->{action} } @value;
            
            # add action, if any, to the subrule
            $value[3]->{action} = shift @action if @action;
            # add subrule under its name denoted by identifier
            $per_parse->{subrules}->{$value[1]} = $value[3];

            # set up factor as the subrule's lhs set by <identifier> 
            # rather than the subrule's contents
            my $factor = { symbol => $value[1] };

            # add quantifier, if any, to the subrule's lhs (not $per_parse->{subrules}
            $factor->{symbol} .= shift @quantifier if @quantifier;

            # return factor
            $factor;
        %}
    
  
  quantifier    ::= '?' %{ { quantifier => $_[1] } %}
  quantifier    ::= '*' %{ { quantifier => $_[1] } %}
  quantifier    ::= '+' %{ { quantifier => $_[1] } %}

  symbol        ::= identifier | literal
  identifier    ::= 'qr/[\w\d\-]+/'
  literal       ::= 'qr/".+?"/' | "qr/'.+?'/"
    
};

my $ebnf_bnf = MarpaX::Parse->new({
    rules => $ebnf_in_bnf,
    default_action => 'AoA',
    quantifier_rules => 'recursive', # this toglles on nullables in quantifiers
#    show_bnf_tokens => 1,
    nullables_for_quantifiers => 1,
});

isa_ok $ebnf_bnf, 'MarpaX::Parse';

#say $ebnf_bnf->show_rules;

#
# if a production has one action, this one action is treated as a production's action
# to add an action to the last rule of the production, add empty action %{%} after it
#
#    r ::= ( s1 s2 )+


# example grammar (comments are not supported yet)
# actions can be defined for symbols that are re-written to 
# separate rules, such as groups (in parens), alternatives, and 
# whole productions, e.g. %{ action(<add_sub_op>) %}, 
# %{ action(<'9'>) %}, and %{ action(<digit>) %}, accordingly
my $arithmetic = q{

    expression  ::= 

        term                            

        ( (add_sub_op: '+' | '-' ) %{ action(<add_sub_op>) %} term )* 
            
            %{ action(anonymous subrule <()*>) %} 
            
        %{ action(expression) %}
        
    term        ::= factor  ( (mul_div_op: '*' | '/' ) %{ action of <mul_div_op> %} factor)*
    factor      ::= constant | variable | '('  expression  ')'
    variable    ::= 'x' | 'y' | 'z'
    constant    ::= digit+ (frac:'.' digit+)?
    digit       ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' %{ action(<'9'>) %} %{ action(<digit>) %}
    
};

my $arithmetic_rules = $ebnf_bnf->parse($arithmetic);

say "# arithmetic rules:\n", Dump $arithmetic_rules;

# set up decimal number bnf
my $arithmetic_bnf = MarpaX::Parse->new({
    rules => $arithmetic_rules,
    default_action => 'tree',
    quantifier_rules => 'recursive',
    nullables_for_quantifiers => 1,
});

say $arithmetic_bnf->show_rules;
say $arithmetic_bnf->show_closures;

# test decimal number bnf
my $expressions = [
# numbers
    '1234.132',
    '-1234',
# actions
    '1234 + 4321',
    '(1234 + 1234) / 123',
# variables
    'x + 1',
    '(x + 1) + 2',
    '((x + 1) / 4) + 2',
    '(x + y) / z) + 2'
];

for my $expr (@$expressions){

    # parse tree is in XML string (default_action => 'xml')
    my $value = $arithmetic_bnf->parse($expr);
    
    unless (is $value, $expr, "expression $expr lexed and parsed with EBNF"){
        say $arithmetic_bnf->show_parse_tree;
    }
}
