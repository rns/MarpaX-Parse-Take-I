use 5.010;
use strict;
use warnings;

use Test::More tests => 6;

use YAML;

use_ok 'Marpa::Easy';

=head1 Test Scheme

BNF in BNF:

    (1) Marpa::Easy->new will parse textual BNF to produce a Marpa grammar able to parse BNF grammars;

    (2) That Marpa grammar will parse the decimal numbers BNF grammar and produce a Marpa grammar able to parse decimal numbers; and

    (3) That decimal numbers Marpa grammar will parse decimal numbers
    
    The grammar below has rules with quantifiers
    
        rule    ::= symbol+ | symbol+ action
    
    and recursive sequence with proper separators because BNF (unlike EBNF) has no brackets for grouping
    
        rules   ::= rule | rule '|' rules   
    
=cut

my $bnf_in_bnf = q{

    grammar    ::= production+
        %{
            # flatten array of arrays unless it has only one item
            return @{ $_[1] } > 1 ? [ map { @$_ } @{ $_[1] } ] : $_[1];
        %}
    production ::= lhs '::=' rhs
        %{
            use Eval::Closure;
            
            my $lhs = $_[1];
            my @rhs = @{ $_[3] };
            my $rules = [];

            for my $rhs (@rhs){

                my ($symbols, $action ) = map { $rhs->{$_} } qw{ symbols action };
                $symbols = ref $symbols eq "ARRAY" ? $symbols : [ $symbols ];

                my $rule = {
                    lhs => $lhs,
                    rhs => $symbols,
                };

                if (defined $action){
                    my $closure = eval_closure(
                        source => $action,
                        description => 'action of rule ' . $rule_signature,
                    );
                    $rule->{action} = $closure;
                }
                push @$rules, $rule;
            }
            $rules;
        %}
    lhs        ::= symbol
    rhs        ::= rules
    
    rules      ::= 
        rule 
            %{
                [ $_[1] ]                   # init separated rule sequence  
            %}
        | 
        rule '|' rules
            %{
                unshift @{ $_[3] }, $_[1];  # prepend next rule, skip separator
                $_[3];                      # return rules aref
            %}

# rule ::= symbol+ action? could be used, but the action of 'rules ::=' rule above
# would be more complicated then due to the necessity to check for if action is defined
    rule       ::= 
          symbol+ 
            %{ 
                my $rule = {};

                # add symbols
                $rule->{symbols} = $_[1];

                $rule;
            %}
            
        | symbol+ action 
            %{ 
                say "# rule:\n", Dump \@_;

                my $rule = {};

                # add symbols
                $rule->{symbols} = $_[1];

                # set action, if any
                $rule->{action} = $_[2] if defined $_[2];

                $rule;
            %}

    action     ::= 'qr/%{.+?%}/'
    
    symbol     ::= literal | identifier

    literal    ::= 'qr/".+?"/' | "qr/'.+?'/"

    identifier ::= 'qr/\w+(\?|\*|\+)?/'
    
};

my $bnf_bnf = Marpa::Easy->new({
    rules => $bnf_in_bnf,
    default_action => 'AoA',
});

isa_ok $bnf_bnf, 'Marpa::Easy';

# example grammar (comments are not supported yet)
my $decimal_numbers_grammar = q{
    expr    ::= '-' num | num
    num     ::= digits | digits '.' digits
    digits  ::= digit | digit digits
    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
};

my $decimal_number_rules = $bnf_bnf->parse($decimal_numbers_grammar);

# set up decimal number bnf
my $decimal_number_bnf = Marpa::Easy->new({
    rules => $decimal_number_rules,
    default_action => 'xml',
});

# test decimal number bnf
my $numbers = [
    '1234',
    '-1234.423',
    '-1234',
    '1234.423',
];

use XML::Twig;

for my $number (@$numbers){

    # parse tree is in XML string (default_action => 'xml')
    my $xml = $decimal_number_bnf->parse($number);

    # setup XML parse tree
    my $t = XML::Twig->new;
    $t->parse($xml);

=item
    Each parse tree represents a string of terminals s, which we call Yield of a tree the yield of the tree. The string s consists of the labels of the leaves of the tree, in left-to-right order. — http://i.stanford.edu/~ullman/focs/ch11.pdf
=cut
    my $deparsed_number = $t->root->text;

    # test
    is $deparsed_number, $number, "numeral $number lexed and parsed with BNF";

}
