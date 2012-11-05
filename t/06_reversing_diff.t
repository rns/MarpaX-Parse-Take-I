use strict;
use warnings;

use Test::More tests => 1;

use YAML;

use 5.010;
use MarpaX::Parse;

# this silences "Possible attempt to separate words with commas", among others
no warnings;

my $rules = [

    [ DiffOutput => [qw( 
            Command+
      )], 
      sub {
            join '', @{ $_[1] };
      }
    ],

    [ Command    => [qw(
            LineNum 'a' LineRange RightLine+
      )],
      sub { 
            "$_[3]d$_[1]\n" . join '', map {s/>/</; $_} @{ $_[4] }
      }
    ],  
    [ Command    => [qw( 
            LineRange 'd' LineNum LeftLine+
      )],
      sub { 
            "$_[3]a$_[1]\n" . join '', map {s/</>/; $_} @{ $_[4] }
      }
    ],  
    [ Command    => [qw( 
            LineRange 'c' LineRange LeftLine+ 'qr/---\n/' RightLine+
      )],
      sub {
            "$_[3]c$_[1]\n" .
            join( '', map {s/>/</; $_} @{ $_[6] } ) . 
            "$_[5]" .
            join( '', map {s/</>/; $_} @{ $_[4] } )
      }  
    ],  
        
    [ LineRange  => [qw( 
            LineNum ',' LineNum
      )],
      sub { 
            join '', @_[1..3]
      }
    ],  
    [ LineRange  => [qw( LineNum        )] ],
        
    [ LineNum    => [qw( 'qr/\d+/'      )] ],
    [ LeftLine   => [qw( 'qr/<.*\n/'    )] ],
    [ RightLine  => [qw( 'qr/>.*\n/'    )] ],

];

use warnings;

# input
my $diff = q{
17,18d16
< (who writes under the
< pseudonym "Omniscient Trash")
45,46c43,44
< soon every Tom, Dick or Harry
< will be writing his own Perl book
---
> soon every Tom, Randal and Larry
> will be writing their own Perl book
69a68,69
> Copyright (c) 1998, The Perl Journal.
> All rights reserved.
};

# expected
my $reversed_diff = q{16a17,18
> (who writes under the
> pseudonym "Omniscient Trash")
43,44c45,46
< soon every Tom, Randal and Larry
< will be writing their own Perl book
---
> soon every Tom, Dick or Harry
> will be writing his own Perl book
68,69d69
< Copyright (c) 1998, The Perl Journal.
< All rights reserved.
};

my $me = MarpaX::Parse->new({
    rules => $rules,
    default_action => 'AoA',
});

my $value = $me->parse($diff);

is $value, $reversed_diff, "diff reversed (example from Parse::RecDescent tutorial)";

