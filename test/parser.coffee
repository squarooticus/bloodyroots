{ Parser } = require('../lib/bloodyroots')

describe 'Parser', ->
  describe 'unit tests', ->
    describe 'at_least_one', ->
      class TestParser1 extends Parser
        @defp('Document', @at_least_one( @re('abc')))

      p = new TestParser1()

      describe 'with none', ->
        r = p.parse('dabc')
        it 'should fail', ->
          assert not r?

      describe 'with one', ->
        r = p.parse('abcdef')
        r_correct = `{ pos: 0,
  length: 3,
  type: 'seq',
  seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
        it 'should parse', ->
          assert deep_equal(r, r_correct)
    
      describe 'with two', ->
        r = p.parse('abcabc')
        r_correct = `{ pos: 0,
  length: 6,
  type: 'seq',
  seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
    { pos: 3, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
        it 'should parse', ->
          assert deep_equal(r, r_correct)
    
    describe 'range', ->
      class TestParser1 extends Parser
        @defp('Document', @v('non-greedy-test-1'))
        @defp('non-greedy-test-1', @range_nongreedy( @re('abc'), 3, 7, @re('abcdef')))

      class TestParser2 extends Parser
        @defp('Document', @seq( @v('non-greedy-test-2'), @re('abcdef')))
        @defp('non-greedy-test-2', @range( @re('abc'), 3, 7))

      c = new TestParser1()
      d = new TestParser2()

      describe 'with range_nongreedy', ->
        r2 = c.parse('abcabcabcabcdef')
        r2_correct = `{ pos: 0,
          length: 15,
          type: 'seq',
          seq: 
           [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
             { pos: 3, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
             { pos: 6, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
             { pos: 9,
               length: 6,
               type: 're',
               match: 'abcdef',
               groups: [ 'abcdef' ] } ] }`

        it 'should parse greedy trap', ->
          assert deep_equal(r2, r2_correct)

      describe 'with range', ->
        r3 = d.parse('abcabcabcabcdef')

        it 'should fail on greedy trap', ->
          assert not r3?

  describe 'with BBCode', ->
    element = (elt) ->
      {
        type: 'element',
        tag: elt.seq[0].groups[1],
        arg: elt.seq[0].groups[2],
        contents: elt.seq[1],
      }

    seq2array = (elt) -> elt.seq

    text = (elt) ->
      {
        type: 'text',
        text: elt.match,
      }

    class BBCodeParser extends Parser
      debug = true
      
      @defp('Document',
        @transform(seq2array,
          @zero_or_more(
            @first(
              @v('Element'),
              @v('TagOrText')))))

      @defp('Element',
        @transform(element,
          @seq(
            @re('\\[([A-Za-z]*)(?:=([^\\]]*))?\\]', 'opentag'),
            @transform(seq2array,
              @zero_or_more(
                @first(
                  @v('Element'),
                  @v('NotSpecificCloseTag', @backref('opentag[1]'))))),
            @var_re('\\[/\\=opentag[1]\\]'))))

      @defp('NotSpecificCloseTag',
        @transform(text, @var_re('\\[/(?!\\=arg[0]\\])[^\\]]*\\]|\\[(?:[^/][^\\]]*)?\\]|[^\\[]+')))

      @defp('TagOrText', @transform(text, @re('\\[[^\\]]*\\]|[^\\[]+')))

    b = new BBCodeParser()

    describe 'basic test case', ->
      r = b.parse('[zoo][/zoo][/i][q][b=1]text[w][a]text2[/a][/b]')
      r_correct = `[ { type: 'element', tag: 'zoo', arg: undefined, contents: [] },
        { type: 'text', text: '[/i]' },
        { type: 'text', text: '[q]' },
        { type: 'element',
          tag: 'b',
          arg: '1',
          contents: 
           [ { type: 'text', text: 'text' },
             { type: 'text', text: '[w]' },
             { type: 'element',
               tag: 'a',
               arg: undefined,
               contents: [ { type: 'text', text: 'text2' } ] } ] } ]`

      it 'should output DOM matching model', ->
        assert deep_equal(r, r_correct)

    describe 'newline', ->
      r = b.parse('[zoo]abc\ndef[/zoo]')
      r_correct = `[ { type: 'element', tag: 'zoo', arg: undefined, contents: [ { type: 'text', text: 'abc\ndef' } ] } ]`

      it 'should be accepted as text', ->
        assert deep_equal(r, r_correct)

