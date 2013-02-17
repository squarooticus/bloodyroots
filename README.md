# Bloody Roots

A JavaScript engine for recursive descent parsing of context-free grammars, written in CoffeeScript.

## Usage:

1. `{ Parser } = require('bloodyroots')`
2. Create a new class extending from `Parser`, defining one or more productions. The `Document` production is required, as it will be the parse engine's entry point into the grammar.
3. Instantiate the derived parser class.
4. Execute the parse method on this instance. It will return a DOM tree on successful parse, or undefined on failure.

## Suggestions:

See `parser.coffee` in `test/` for a good example of how to implement a grammar: `BBCodeParser` is an early version of what I wrote this code for. It parses a variant of BBCode that I use in my old Perl-based forum software that is now long in the tooth.

## To do:

1. Provide systematic logging for assistance in developing grammars.
2. Memoize the output of parsing whole productions for optimization of backtracking, keyed on production name, `idx`, and input `vdata`
3. Implement more comprehensive test coverage.
4. Clean up the code and structure as I learn Node.js better. Please provide feedback if something is not working as it should within the ecosystem: it has been difficult to piece together the "right" way to do things through the results of Google searches.

## License

The MIT License

Copyright (c) 2013 Kyle Rose

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


