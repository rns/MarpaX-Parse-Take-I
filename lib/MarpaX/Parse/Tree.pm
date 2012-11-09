package MarpaX::Parse::Tree;

use 5.010;
use strict;
use warnings;

# TODO: load modules on demand
use Module::Runtime qw{ use_module };

use Marpa::R2;

use Tree::Simple 'use_weak_refs';
use Tree::Simple::Visitor;
use Tree::Simple::View::DHTML;
use Tree::Simple::View::HTML;

use Data::TreeDumper;

use XML::Twig;

use Text::Balanced qw(extract_delimited extract_bracketed);

sub new
{
    my $class = shift;
    my $options = shift;
        
    my $self = {};

    # get options
    $self->{g} = $options->{grammar};
    $self->{t} = $options->{type};
    
    # load the modules for the tree type on demand
    # at the moment, AoA HoA HoH xml sexpr and tree are supported
    if ($self->{t} eq "tree"){
        use_module 'Tree::Simple';
        Tree::Simple::import('use_weak_refs');
        use_module 'Tree::Simple::Visitor';
        use_module 'Tree::Simple::View::DHTML';
        use_module 'Tree::Simple::View::HTML';
        use_module 'Data::TreeDumper';
    }
    elsif ($self->{t} eq "xml"){
        use_module 'XML::Twig';
    }
    elsif ($self->{t} eq 'sexpr'){
        use_module 'Text::Balanced';
        Text::Balanced->import(qw(extract_delimited extract_bracketed));
    }
    else{
        use_module 'Data::TreeDumper';
    }
  
    bless $self, $class;
}

sub AoA { 

    # The per-parse variable.
    shift;

    # Throw away any undef's
    my @children = grep { defined } @_;
    
    # Return what's left as an array ref or a scalar
    scalar @children > 1 ? \@children : shift @children;
}

sub HoA { 

    # The per-parse variable.
    shift;

    # Throw away any undef's
    my @children = grep { defined } @_;
    
    # Get the rule's lhs
    my $lhs = ($Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule))[0];
    
    # Return what's left as an array ref or a scalar named after the rule's lhs
    return { $lhs => scalar @children > 1 ? \@children : shift @children }
}

sub HoH { 

    # The per-parse variable.
    shift;

    # Get the rule's lhs
    my $lhs = ($Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule))[0];

    # Throw away any undef's
    my @children = grep { defined } @_;
    
    # Return what's left as an array ref or a scalar
    my $result = {};
#    say "# children of $lhs\n", Dump \@children;
    if (@children > 1){
        for my $child (@children ){
            if (ref $child eq "HASH"){
#                say "# child of $lhs (HASH):\n", Dump $child;
                for my $key (keys %$child){
                    # replace duplicate key to array ref
                    if (exists $result->{$lhs}->{$key}){
                        $result->{$lhs}->{$key} = [ values %{ $result->{$lhs} } ] 
                            unless ref $result->{$lhs}->{$key} eq "ARRAY";
                        push @{ $result->{$lhs}->{$key} }, values %{ $child };
                    }
                    else{
                        $result->{$lhs}->{$key} = $child->{$key};
                    }
                }
            }
            elsif (ref $child eq "ARRAY"){
#                say "# child of $lhs (ARRAY):\n", Dump $child;
                # issue warning when destination key already exists
                if (exists $result->{$lhs}){
                    say "This value of {$lhs}:\n", Dump($result->{$lhs}), "will be replaced with:\n", Dump($child);
                }
                $result->{$lhs} = $child;
            }
        }
    }
    else {
        $result->{$lhs} = shift @children;
    }        
    return $result;
}

sub AoA_with_rule_signatures { 

#    say "# AoA_with_rule_signatures ", Dump \@_;

    # per-parse variable.
    shift;
    
    # Throw away any undef's
    my @children = grep { defined } @_;
    
    # Return what's left as an array ref or a scalar
    my $result = scalar @children > 1 ? \@children : shift @children;
    
    # Get the rule lhs and rhs and make the rule signature
    my ($lhs, @rhs) = $Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule);
    my $rule = $lhs . ' -> ' . join ' ', @rhs;

    $result = [ $result ];
    unshift @$result, $rule;

    return $result;
}

# s-expression
sub sexpr { 
    
    # The per-parse variable.
    shift;
    
    # Get the rule's lhs
    my $lhs = ($Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule))[0];
    
    # Throw away any undef's
    if (my @children = grep { defined } @_){
        return "($lhs " . join(' ', map { ref $_ eq "ARRAY" ? join ' ', @$_ : $_ } @children) . ")";
    }
    
    return undef; 
}

sub tree { 

    # The per-parse variable.
    shift;
    
    my @children = grep { defined } @_;
    
    if (@children){
#        say "# tree:\n", Dump [ map { ref $_ eq 'Tree::Simple' ? ref $_ : $_ } @children ];

        # get the rule's lhs
        my $lhs = ($Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule))[0];

        # set up the parse tree node
        my $node = Tree::Simple->new($lhs);
        $node->addChildren(
            map { 
                    ref $_ eq 'Tree::Simple' 
                        ? $_ 
                        : ref $_ eq "ARRAY" 
                            ? map { ref $_ eq 'Tree::Simple' 
                                ? $_ 
                                    : Tree::Simple->new($_) } grep { defined $_ } @$_ 
                                : Tree::Simple->new($_) 
                } 
                @children
        );

        return $node;
    }

    return undef;
}

# remove unneeded Tree::Simple information from Data::TreeDumper's output
sub filter
{
    my $s = shift;

    if('Tree::Simple' eq ref $s){
        my $counter = 0;
        return (
            'ARRAY', 
            $s->{_children}, 
            # index generation
            map 
                { 
                    [ $counter++, $_->{_node} ] 
                } 
                @{ 
                    $s->{_children}
                }
        );
    }
    
    return(Data::TreeDumper::DefaultNodesToDisplay($s)) ;
}

sub xml {

#    say Dump \@_;
    
    # The per-parse variable.
    shift;
    
    # Get the rule's lhs
    my $lhs = ($Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule))[0];
    
    # replace symbols quantifier symbols (not valid in XML tags) with plural (hopefully)
    $lhs =~ s/(\+|\*)$/s/;
    
    #
    # TODO: if start symbol, prepend <?xml version="1.0" encoding="UTF-8" standlone="yes"?>
    # to the return value and convert it to UTF-8.
    # Note: this requires start() accessor of Marpa::R2::Grammar
    #
    
    # wrap xml element
    return 
          "<$lhs>" 
        . join( "", map { ref $_ eq "ARRAY" ? join "", @$_ : $_ } grep { defined } @_ ) 
        . "</$lhs>";
}

sub show_parse_forest{
    my $self = shift;
    my $format = shift || 'text';

    # POSSIBLE TODO: use start symbol to denote parse trees, if we extracted one
    my $header = 'Parse Tree'; # another use case for start() accessor of Marpa::R2::Grammar

    my $forest = '';
    for my $i (0..@{$self->{parse_forest}}-1){
        $forest .= join '',
            "# $header ", $i + 1, ":\n" ,
            $self->show_parse_tree($self->{parse_forest}->[$i], $format) , 
            "\n";
    }
    chomp $forest;
    return $forest;
}

sub show_parse_tree{
    my $self = shift;
    my $tree = shift || $self->{parse_tree};
    my $format = shift || 'text';
    
#    say Dump $tree;
    
    # if we have not $tree passed and there is a parse forest,
    # then show_parse_forest in default format 
    return $self->show_parse_forest if not defined $tree and $self->{parse_forest};
    
    # tree proper
    if (ref $tree eq "Tree::Simple"){
        given ($format){
            when ("text"){
                return DumpTree( 
                        $tree, $tree->getNodeValue,
                        DISPLAY_ADDRESS => 0,
                        DISPLAY_OBJECT_TYPE => 0,
                        FILTER => \&filter
                    );
            }
            when ("html"){
                my $tree_view = Tree::Simple::View::HTML->new($tree);    
                return $tree_view->expandAll();
            }
            when ("dhtml"){
                my $tree_view = Tree::Simple::View::DHTML->new($tree);    
                return 
                      $tree_view->javascript()
                    . $tree_view->expandAll();
            }
        }
    }
    # data structure
    elsif (ref $tree ~~ [ "ARRAY", "HASH" ] ){
        return DumpTree($tree, "tree",
            DISPLAY_ADDRESS => 0,
            DISPLAY_OBJECT_TYPE => 0,
        )
    }
    # string starting with xmldecl when lowercased, must be XML
    elsif ($self->{t} eq "xml") {
        my $t = XML::Twig->new(pretty_print => 'indented');
        $t->parse($tree);
        return $t->sprint;
    }
    elsif ($self->{t} = 'sexpr'){
        # TODO: pretty-printer for s-expressions
        return $tree
    }
    # mere scalar
    else{
        return $tree;
    }
}

1;

