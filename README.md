# Bloody Roots

A JavaScript engine for recursive descent parsing of context-free grammars, written in CoffeeScript.

## Usage

1. `{ Parser } = require('bloodyroots')`
2. Create a new class extending from `Parser`, defining one or more productions. The `Document` production is required, as it will be the parse engine's entry point into the grammar.
3. Instantiate the derived parser class.
4. Execute the parse method on this instance. It will return a DOM tree on successful parse, or undefined on failure.

## Terminology

Context free grammars use productions of the form α→β, where α is a single non-terminal and β is a sequence of terminals and non-terminals; throughout the rest of this document, β refers to some tree of grammar operations, defined below. Please see http://en.wikipedia.org/wiki/Context-free_grammar for more detailed information on context-free grammars.

`vdata` refers to an object that tracks parametric information for parsing the β tree associated with a particular α, typically containing the capture group information for previous regular expression matches.

## Grammar operations

It is useful to understand regular expressions, as the grammar operations in this parser correspond to regular expression operations.

-	`@alternation(β_1, β_2, ..., β_n)` or `@alternation( [β_1, β_2, ..., β_n], suffix)`: Equivalent to the `...|...|...` from regular expressions: given a sequence of βs, it produces a parse tree from the first β that parses. Unlike regular expressions, however, the default behavior is to commit to a particular β from the given sequence and not backtrack if what follows does not parse. So, for example, while `(aaa|aa)ab` will match the string `aaab`, the β tree

		@seq(@alternation(@re('aaa'), @re('aa')), @re('ab'))

	will not parse `aaab` because `@re('aaa')` will have matched and the alternation considered committed before checking whether `@re('ab')` matches. The regular expression-like behavior can be achieved by specifying the alternation's β sequence as an array in the first argument and the suffix as the second argument:

		@alternation([@re('aaa'), @re('aa')], @re('ab'))

	Note, however, that this will result in backtracking and so is less efficient than writing a different set of productions for the same grammar that does not require backtracking.

	When `suffix` is specified, returns a DOM tree node of `type: 'seq'` with the matching β as the first element and the suffix as the second element of an array under key `seq`; when `suffix` is not specified, returns precisely what parsing β returned.

-	`@range(β, min=0, max, greedy=true, suffix)`: Equivalent to `(...){n,m}` from regular expressions: it matches at least `n` and at most `m` repetitions of the given β. As with `@alternation`, one needs to specify a `suffix` to force backtracking if the range match should not commit after finding the minimum `>= min` (non-greedy) or the maximum `<= max` (greedy) number of consecutive matches. There are several shorthands based on `@range`:

	-	`@at_least_one(β, suffix)` is equivalent to `@range(β, 1, undefined, true, suffix)`: think `+` from regular expressions.
	-	`@zero_or_more(β, suffix)` is equivalent to `@range(β, 0, undefined, true, suffix)`: think '*' from regular expressions.
	-	`@zero_or_one(β, suffix)` is equivalent to `@range(β, 0, 1, true, suffix)`: think '?' from regular expressions (as applied to a terminal, not as applied to force non-greediness)

	Note that using non-greediness without a suffix always returns either `min` matches or fails to parse.

	Returns a DOM tree node of `type: 'seq'` with an array of each matched β (plus the matched suffix, if any) under key `seq`.

-	`@re(re_str, match_name)`: Matches the given regular expression. If `match_name` is specified, then the resulting match array (index `0` being the full matched string, index `n>=1` being the `n`th capture group) is assigned the given name. See `@var_re` for the use of this named match array.

	Returns a DOM tree node of `type: 're'` with the entire string under key `match` and the named groups (including the entire string again under index 0) as an array under key `groups`.

-	`@seq(β_1, β_2, ..., β_n)`: Matches the given βs in order.

	Returns a DOM tree node of `type: 'seq'` with the array of matching βs under key `seq`.

-	`@transform(f, β)`: Transforms the DOM tree resulting from parsing β using the function `f`, which takes the DOM tree, `vdata`, and the string index of the parsed substring as arguments. `this` is set to the instance of the parser.

	Returns whatever the transform returns; `undefined` is considered a failure to parse. The transform should not modify the input parse tree, as the original may be part of a cached entry (see [Optimizations](#optimizations) for more info) and so cause unintended behavior elsewhere in the parser.

-	`@v(alpha_s, argf)`: Parses the α named `alpha_s`, as defined by `@define_production(alpha_s, ...)`.

	If `argf` is specified, calls `argf.call(this, vdata)` and assigns the return value to the `vdata.arg` which is passed to the grammar operations for α=`alpha_s`. The purpose of this second argument is to make the receiving productions variable functions of this parameter, specifically to pass backreferences from an earlier `@re` match to another production.

	If, for instance, one wishes to parse XML without needing to know all schema-valid tags in advance, one needs to match a close tag to the tag that opened it. This can be performed with a non-greedy alternation, but a more efficient way to accomplish this is to use greediness combined with a forward-looking negative regular expression match on the open tag, such as in the BBCode parser from the test code:

		@define_production('Element',
		  @seq(
		    @re('\\[([A-Za-z]*)(?:=([^\\]]*))?\\]', 'opentag'),
		    @zero_or_more(
		      @alternation(
		        @v('Element'),
		        @v('NotSpecificCloseTagOrText', @backref('opentag[1]'))))),
		    @var_re('\\[/\\=opentag[1]\\]'))))

		@define_production('NotSpecificCloseTagOrText',
		  @transform(text, @var_re('\\[/(?!\\=arg[0]\\])[^\\]]*\\]|\\[(?:[^/][^\\]]*)?\\]|[^\\[]+')))

	In the first step of the `@seq`, `Element` searches for an open tag and assigns the name of the tag to `vdata.opentag`. In the second step it then parses zero or more `Element`s or `NotSpecificCloseTagOrText`s: the first case parses a full subelement (such as `[b]...[/b]`); the second case, however, parses any text or close tag *except* the close tag that matches `vdata.opentag[1]` (as `vdata.arg[0]` from `NotSpecificCloseTag`'s `vdata`). In that case, the `@zero_or_more` is done and the `@var_re` matches the specific close tag in the final step of the `@seq`.

	Clearly, this could all be done within the `Element` production itself, but one can imagine another use of `NotSpecificCloseTagOrText` that might motivate breaking it out into its own production.

	See `@var_re` for information on how the argument is inserted into the regular expression.

	Returns precisely what the production for the given `alpha_s` would return.

-	`@var_re(re_str, match_name)`: Same as `@re`, but replaces all instances of `=arg[idx]` with `vdata.arg[idx]`. Note that this regular expression cannot be precompiled and so `@var_re` is less efficient than `@re`.

## The DOM tree

An object tree representing the parser output. In each node, standard keys always present are `pos` and `length`, indicating respectively the starting index of and the length of the input string whose parsed output is represented by this subtree; and `type`, indicating the type of element represented by this node. Other keys for a node depend on the output of the grammar operation used to parse it.

## Suggestions

Specify `@debug = true` in your class definition to turn on debug logging for instances of that parser: this should help with development of tricky grammars.

See `test/parser.coffee` for a good example of how to implement a grammar: `BBCodeParser` is an early version of what I wrote this code for. It parses a variant of BBCode that I use in my old Perl-based forum software that is now long in the tooth and probably full of security holes. (Sssh! Don't tell anyone.)

## <a id="optimizations"></a>Optimizations

If, as a result of backtracking, a particular α is parsed multiple times at the same string position with the same `vdata`, the second and subsequent attempts will return the previously cached result instead of re-parsing the string. This caching is evident in the full debug log.

## To do

1. Clean up the code and structure as I learn Node.js better. Please provide feedback if something is not working as it should within the ecosystem: it has been difficult to piece together the "right" way to do things through the results of Google searches.
2. Simplify the logic in `match_range`. Yuck: that function is way too long because it deals with 2 cases (greedy and non-greedy) that are very different from each other.

## License

The MIT License

Copyright (c) 2013 Kyle Rose

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


