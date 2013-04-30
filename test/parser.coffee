String.prototype.repeat = (num) ->
    new Array( num + 1 ).join( this );

describe 'Parser', ->
    describe 'unit testing', ->
        describe 'at_least_one', ->
            class TestParser extends Parser
                @define_production('Document', @at_least_one(@re('abc')))

            p = new TestParser()

            describe 'with none', ->
                r = p.parse('dabc')
                
                it 'should not parse', -> assert not r?

            describe 'with one', ->
                r = p.parse('abcdef')
                r_correct = `{ pos: 0,
                    length: 3,
                    type: 'seq',
                    seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
    
                it 'should parse', -> assert deep_equal(r, r_correct)
        
            describe 'with two', ->
                r = p.parse('abcabcdef')
                r_correct = `{ pos: 0,
                    length: 6,
                    type: 'seq',
                    seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
                        { pos: 3, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
        
                it 'should parse', -> assert deep_equal(r, r_correct)
        
        describe 'zero_or_more', ->
            class TestParser extends Parser
                @define_production('Document', @zero_or_more(@re('abc')))

            p = new TestParser()

            describe 'with none', ->
                r = p.parse('dabc')
                r_correct = `{ pos: 0,
                    length: 0,
                    type: 'seq',
                    seq: [ ] }`
                
                it 'should parse', -> assert deep_equal(r, r_correct)

            describe 'with one', ->
                r = p.parse('abcdef')
                r_correct = `{ pos: 0,
                    length: 3,
                    type: 'seq',
                    seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
    
                it 'should parse', -> assert deep_equal(r, r_correct)
        
            describe 'with two', ->
                r = p.parse('abcabcdef')
                r_correct = `{ pos: 0,
                    length: 6,
                    type: 'seq',
                    seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] },
                        { pos: 3, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
        
                it 'should parse', -> assert deep_equal(r, r_correct)
        
        describe 'zero_or_one', ->
            class TestParser extends Parser
                @define_production('Document', @zero_or_one(@re('abc')))

            p = new TestParser()

            describe 'with none', ->
                r = p.parse('dabc')
                r_correct = `{ pos: 0,
                    length: 0,
                    type: 'seq',
                    seq: [ ] }`
                
                it 'should match zero times', -> assert deep_equal(r, r_correct)

            describe 'with one', ->
                r = p.parse('abcdef')
                r_correct = `{ pos: 0,
                    length: 3,
                    type: 'seq',
                    seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
    
                it 'should match one time', -> assert deep_equal(r, r_correct)
        
            describe 'with two', ->
                r = p.parse('abcabcdef')
                r_correct = `{ pos: 0,
                    length: 3,
                    type: 'seq',
                    seq: [ { pos: 0, length: 3, type: 're', match: 'abc', groups: [ 'abc' ] } ] }`
        
                it 'should match one time', -> assert deep_equal(r, r_correct)

        describe 'alternation', ->
            describe 'parsing abcde with (abc|ab)cde', ->
                # suffix
                describe 'with suffix', ->
                    class TestParser extends Parser
                        @define_production('Document', @alternation( [ @re('abc'), @re('ab') ], @re('cde')))
                    p = new TestParser()
                    r = p.parse('abcde')

                    it 'should parse', -> assert r? and r.length == 5

                describe 'without suffix', ->
                    class TestParser extends Parser
                        @define_production('Document', @seq(@alternation(@re('abc'), @re('ab')), @re('cde')))
                    p = new TestParser()
                    r = p.parse('abcde')

                    it 'should not parse', -> assert not r?
                    
        describe 'range', ->
            describe 'parsing abc{m}abc{k}def with abc{i,j}def', ->
                for i in [0..6]
                    do (i) ->
                        for j in [0..6].concat(undefined)
                            do (j) ->
                                for k in [0..1]
                                    do (k) ->
                                        # non-greedy no-suffix
                                        class TestParser extends Parser
                                            @define_production('Document', @seq(@range(@re('abc'), i, j, false), @re('abc'.repeat(k) + 'def')))
                                        p = new TestParser()

                                        for m in [0..5]
                                            do (m) ->
                                                describe 'with non-greedy no-suffix m=%d k=%d i=%d j=%d'.sprintf(m,k,i,j), ->
                                                    r = p.parse('abc'.repeat(m) + 'def')

                                                    if i + k == m and (not j? or i <= j)
                                                        it 'should succeed', -> assert r?
                                                    else
                                                        it 'should fail', -> assert not r?

                                        # greedy no-suffix
                                        class TestParser extends Parser
                                            @define_production('Document', @seq(@range(@re('abc'), i, j, true), @re('abc'.repeat(k) + 'def')))
                                        p = new TestParser()

                                        for m in [0..5]
                                            do (m) ->
                                                describe 'with greedy no-suffix m=%d k=%d i=%d j=%d'.sprintf(m,k,i,j), ->
                                                    r = p.parse('abc'.repeat(m) + 'def')

                                                    if k == 0
                                                        if i <= m and (not j? or j >= m)
                                                            it 'should succeed', -> assert r?
                                                        else
                                                            it 'should fail', -> assert not r?
                                                    else
                                                        if j? and j + k == m and i <= j
                                                            it 'should succeed', -> assert r?
                                                        else
                                                            it 'should fail', -> assert not r?

                                        # non-greedy suffix
                                        class TestParser extends Parser
                                            @define_production('Document', @range(@re('abc'), i, j, false, @re('abc'.repeat(k) + 'def')))
                                        p = new TestParser()

                                        for m in [0..5]
                                            do (m) ->
                                                describe 'with non-greedy suffix m=%d k=%d i=%d j=%d'.sprintf(m,k,i,j), ->
                                                    r = p.parse('abc'.repeat(m) + 'def')

                                                    if i + k <= m and (not j? or j + k >= m)
                                                        it 'should succeed', -> assert r?
                                                    else
                                                        it 'should fail', -> assert not r?

                                        # greedy suffix
                                        class TestParser extends Parser
                                            @define_production('Document', @range(@re('abc'), i, j, true, @re('abc'.repeat(k) + 'def')))
                                        p = new TestParser()

                                        for m in [0..5]
                                            do (m) ->
                                                describe 'with greedy suffix m=%d k=%d i=%d j=%d'.sprintf(m,k,i,j), ->
                                                    r = p.parse('abc'.repeat(m) + 'def')

                                                    if i + k <= m and (not j? or j + k >= m)
                                                        it 'should succeed', -> assert r?
                                                    else
                                                        it 'should fail', -> assert not r?

            # distinguishes between greedy suffix and non-greedy suffix
            describe 'parsing ab{k}babab with ([ab]{2}){i,j}bab', ->
                for i in [0..6]
                    do (i) ->
                        for j in [0..6].concat(undefined)
                            do (j) ->
                                # non-greedy suffix
                                class TestParser extends Parser
                                    @define_production('Document', @range(@re('[ab]{2}'), i, j, false, @re('bab')))
                                p = new TestParser()

                                for k in [0..5]
                                    do (k) ->
                                        describe 'with non-greedy suffix {%d,%d} on ab{%d}babab'.sprintf(i,j,k), ->
                                            r = p.parse('ab'.repeat(k) + 'babab')

                                            if not j? or (i <= j and j >= k)
                                                if i <= k
                                                    it 'should have length %d'.sprintf(3+2*k), -> assert r.length == 3+2*k
                                                else if i == k + 1
                                                    it 'should have length %d'.sprintf(5+2*k), -> assert r.length == 5+2*k
                                                else
                                                    it 'should fail', -> assert not r?
                                            else
                                                it 'should fail', -> assert not r?
                

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

