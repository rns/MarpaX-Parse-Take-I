Marpa::R2 allows parsing anything that can be written in BNF. 

This module is intended to move the use of Marpa::R2 closer to the definition of parsing given in [0] by providing

(1) lexical analyzer (based on the grammar terminals) and thus the ability to use a text (rather than symbol) string as an input;

(2) evaluation of Marpa::R2 parse results that represent parse trees as Tree::Simple objects, XML string, S-Expression string, an array of arrays, a hash of arrays, or a hash of hashes;

(3) textual (E)BNF with embedded actions;

(4) automatic handling of ambiguous tokens with (1) Marpa::R2 input model or (2) by merging ambiguous tokens to the grammar; and more, see [1].

A working example of (1) and (3) is in a GitHub repo [1]. This is an adaptation of the "reverse diff" use case specified in Parse::RecDescent tutorial [2]

The repo also contains working examples of (2), (4), and others as shown in README.md [3]—this is what I consider to be an alpha (all tests pass) version of the module that was tentatively named Marpa-Easy, discussed on marpa parser mailing list at [4], and after some refactoring will become MarpaX::Parse. 

I deliberately avoided naming the module MarpaX::Parser as it is not the parser, just an interface to it. The parser is Marpa::R2  [5] by Jeffrey Kegler [6].

[0] http://search.cpan.org/~jkegl/Marpa-R2-2.023_008/pod/Vocabulary.pod

[1] https://github.com/rns/Marpa-Easy-proof-of-concept/blob/master/t/09_reversing_diff_bnf.t

[2] http://cpansearch.perl.org/src/JTBRAUN/Parse-RecDescent-1.967009/tutorial/tutorial.html

[3] https://github.com/rns/Marpa-Easy-proof-of-concept

[4] https://groups.google.com/forum/#!topic/marpa-parser/diKu5kADtvU

[5] http://search.cpan.org/~jkegl/Marpa-R2-2.023_008/

[6] http://www.jeffreykegler.com/
