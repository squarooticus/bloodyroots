{ Parser } = require('../lib/bloodyroots')

String.prototype.repeat = (num) ->
  new Array( num + 1 ).join( this );

describe 'Parser', ->
  describe 'unit tests', ->
    describe 'at_least_one', ->
      class TestParser extends Parser
        @define_production('Document', @at_least_one( @re('abc')))

      p = new TestParser()

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
        r = p.parse('abcabcdef')
        r_correct = `{ pos: 0,
  length: 6,
  type: 'seq',
  seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
    { pos: 3, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
        it 'should parse', ->
          assert deep_equal(r, r_correct)
    
    describe 'testing range', ->
      for i in [0..6]
        for j in [0..6]
          for k in [0..1]
            # non-greedy no-suffix
            class TestParser extends Parser
              @define_production('Document', @seq( @range( @re('abc'), i, j, false), @re('abc'.repeat(k) + 'def')))
            p = new TestParser()

            for m in [0..5]
              describe 'non-greedy no-suffix {%d,%d} on abc{%d}def'.sprintf(i,j,m), ->
                r = p.parse('abc'.repeat(m) + 'def')

                if i + k == m and i <= j
                  it 'should parse', -> assert r?
                else
                  it 'should not parse', -> assert not r?

            # greedy no-suffix
            class TestParser extends Parser
              @define_production('Document', @seq( @range( @re('abc'), i, j, true), @re('abc'.repeat(k) + 'def')))
            p = new TestParser()

            for m in [0..5]
              describe 'greedy no-suffix {%d,%d} on abc{%d}def'.sprintf(i,j,m), ->
                r = p.parse('abc'.repeat(m) + 'def')

                if k == 0
                  if i <= m and j >= m
                    it 'should parse', -> assert r?
                  else
                    it 'should not parse', -> assert not r?
                else
                  if j + k == m and i <= j
                    it 'should parse', -> assert r?
                  else
                    it 'should not parse', -> assert not r?

            # non-greedy suffix
            class TestParser extends Parser
              @define_production('Document', @range( @re('abc'), i, j, false, @re('abc'.repeat(k) + 'def')))
            p = new TestParser()

            for m in [0..5]
              describe 'non-greedy suffix {%d,%d} on abc{%d}def'.sprintf(i,j,m), ->
                r = p.parse('abc'.repeat(m) + 'def')

                if i + k <= m and j + k >= m
                  it 'should parse', -> assert r?
                else
                  it 'should not parse', -> assert not r?

            # greedy suffix
            class TestParser extends Parser
              @define_production('Document', @range( @re('abc'), i, j, true, @re('abc'.repeat(k) + 'def')))
            p = new TestParser()

            for m in [0..5]
              describe 'greedy suffix {%d,%d} on abc{%d}def'.sprintf(i,j,m), ->
                r = p.parse('abc'.repeat(m) + 'def')

                if i + k <= m and j + k >= m
                  it 'should parse', -> assert r?
                else
                  it 'should not parse', -> assert not r?

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
                  @v('NotSpecificCloseTagOrText', @backref('opentag[1]'))))),
            @var_re('\\[/\\=opentag[1]\\]'))))

      @define_production('NotSpecificCloseTagOrText',
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

