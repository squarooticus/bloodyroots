{ Parser } = require('../lib/bloodyroots')

describe 'Parser', ->
  describe 'unit tests', ->
    describe 'at_least_one', ->
      class TestParser1 extends Parser
        @define_production('Document', @at_least_one( @re('abc')))

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
    
    describe 'testing range', ->
      class TestParser1 extends Parser
        @debug = true
        @define_production('Document', @v('range-test-1'))
        @define_production('range-test-1', @range( @re('abc'), 3, 7, false, @re('abcdef')))

      class TestParser2 extends Parser
        @debug = true
        @define_production('Document', @v('range-test-2'))
        @define_production('range-test-2', @range( @re('abc'), 3, 7, true, @re('abcdef')))

      class TestParser3 extends Parser
        @debug = true
        @define_production('Document', @seq( @v('range-test-3'), @re('abcdef')))
        @define_production('range-test-3', @range( @re('abc'), 3, 7, true))

      tp1 = new TestParser1()
      tp2 = new TestParser2()
      tp3 = new TestParser3()

      describe 'non-greedy with suffix', ->
        r = tp1.parse('abcabcabcabcdef')
        r_correct = `{ pos: 0,
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

        it 'should parse', ->
          assert deep_equal(r, r_correct)

      describe 'greedy with suffix', ->
        r = tp2.parse('abcabcabcabcdef')
        r_correct = `{ pos: 0,
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

        it 'should parse', ->
          assert deep_equal(r, r_correct)

      describe 'greedy without suffix', ->
        r = tp3.parse('abcabcabcabcdef')

        it 'should fail', ->
          assert not r?

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
      @define_production('Document',
        @transform(seq2array,
          @zero_or_more(
            @alternation(
              @v('Element'),
              @v('TagOrText')))))

      @define_production('Element',
        @transform(element,
          @seq(
            @re('\\[([A-Za-z]*)(?:=([^\\]]*))?\\]', 'opentag'),
            @transform(seq2array,
              @zero_or_more(
                @alternation(
                  @v('Element'),
                  @v('NotSpecificCloseTag', @backref('opentag[1]'))))),
            @var_re('\\[/\\=opentag[1]\\]'))))

      @define_production('NotSpecificCloseTag',
        @transform(text, @var_re('\\[/(?!\\=arg[0]\\])[^\\]]*\\]|\\[(?:[^/][^\\]]*)?\\]|[^\\[]+')))

      @define_production('TagOrText', @transform(text, @re('\\[[^\\]]*\\]|[^\\[]+')))

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

