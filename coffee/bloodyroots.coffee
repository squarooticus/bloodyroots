re_quote = require('regexp-quote')
inspect_orig = require('util').inspect
inspect = (x) -> inspect_orig(x, false, null)
require('sprintf.js')
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

class Parser
    @define_production: (alpha_s, beta) ->
        @prototype[alpha_s] = (vdata, idx) ->
            beta.op.call this, vdata, idx

    @define_grammar_operation: (name, op_f) ->
        this[name] = (args...) ->
            { name: name, op: if op_f? then op_f.apply this, args else this['match_' + name].apply this, args }

    @define_grammar_operation 'at_least_one', (beta, suffix) -> @match_range(beta, 1, undefined, true, suffix)
    @define_grammar_operation 'alternation'
    @define_grammar_operation 'range'
    @define_grammar_operation 're', (re_str, match_name) -> @match_re(RegExp('^(?:' + re_str + ')'), match_name)
    @define_grammar_operation 'seq'
    @define_grammar_operation 'transform', (f, beta) -> @op_transform(f, beta)
    @define_grammar_operation 'v'
    @define_grammar_operation 'var_re'
    @define_grammar_operation 'zero_or_more', (beta, suffix) -> @match_range(beta, 0, undefined, true, suffix)
    @define_grammar_operation 'zero_or_one', (beta, suffix) -> @match_range(beta, 0, 1, true, suffix)

    @backref: (ref) -> (vdata) ->
        m = /^([^\[]*)\[([0-9]*)\]/.exec(ref)
        [ (vdata[m[1]] || [ ])[m[2]], ]

    debug_log: (f) ->
        if @constructor.debug
            [ name, idx, outcome, data ] = f.call(this)
            '%-15s %3s %-25s %-8s %s\n'.printf name, idx, @string_abbrev(idx, 25), outcome || '', data || ''

    @match_alternation: (args...) ->
        if typeIsArray args[0]
            [ beta_seq, suffix ] = args
        else
            beta_seq = args
        (vdata, idx) ->
            @debug_log -> [ 'alternation', idx, 'begin', 'alternation=%s%s'.sprintf (beta.name for beta in beta_seq), (if suffix? then ' suffix='+suffix.name else ' no-suffix') ]
            i = 0
            for beta in beta_seq
                @debug_log -> [ 'alternation', idx, 'i='+i, beta.name ]
                m = beta.op.call this, vdata, idx
                if m?
                    if suffix?
                        m2 = suffix.op.call this, vdata, idx + m[0]
                        if m2?
                            @debug_log -> [ 'alternation', idx + m[0] + m2[0], 'success', 'count='+(i+1) ]
                            return [ m[0] + m2[0], { pos: idx, length: m[0] + m2[0], type: 'seq', seq: [ m[1], m2[1] ] } ]
                    else
                        @debug_log -> [ 'alternation', idx + m[0], 'success', 'count=%d'.sprintf (i+1) ]
                        return m
                i++
            @debug_log -> [ 'alternation', idx, 'fail' ]
            return

    @match_range: (beta, min=0, max, greedy=true, suffix) ->
        if greedy
            @_match_greedy_range(beta, min, max, suffix)
        else
            @_match_nongreedy_range(beta, min, max, suffix)

    @_match_greedy_range: (beta, min, max, suffix) -> (vdata, idx) ->
        return unless state = @_match_range_to_min(beta, min, max, true, vdata, idx)
        match_indices = [ state.progress ]
        @_match_range_from_min beta, max, vdata, idx, state, =>
            match_indices.push(state.progress)
            false
        while match_indices.length
            state.progress = match_indices.pop()
            @debug_log -> [ 'range', idx + state.progress, 'i='+state.count, 'greedy backtracking' ]
            return result if result = @_match_range_suffix(suffix, vdata, idx, state)
            state.work.pop()
            state.count--
        @debug_log -> [ 'range', idx + state.progress, 'fail', 'greedy backtracking' ]
        return

    @_match_nongreedy_range: (beta, min, max, suffix) -> (vdata, idx) ->
        return unless state = @_match_range_to_min(beta, min, max, false, vdata, idx)
        @_match_range_suffix(suffix, vdata, idx, state) or @_match_range_from_min(beta, max, vdata, idx, state, =>
            @_match_range_suffix(suffix, vdata, idx, state)
        ) or (@debug_log( -> [ 'range', idx + state.progress, 'fail', '>=min non-greedy' ]); undefined)

    _match_range_to_min: (beta, min, max, greedy, vdata, idx) ->
        @debug_log -> [ 'range', idx, 'begin',
            '%s min=%s max=%s %s %s'.sprintf(beta.name, min, (if max? then max else ''),
                (if greedy then 'greedy' else 'non-greedy'),
                (if suffix? then 'suffix='+suffix.name else 'no-suffix')) ]
        if max? and min > max
            @debug_log -> [ 're', idx, 'fail', 'min > max' ]
            return
        state = { count: 0, progress: 0, work: [], greedy: greedy }
        while state.count < min
            @debug_log -> [ 'range', idx + state.progress, 'i='+state.count, '<min' ]
            m = beta.op.call this, vdata, idx + state.progress
            unless m?
                @debug_log -> [ 'range', idx + state.progress, 'fail', '<min matches' ]
                return
            state.progress += m[0]
            state.work.push m[1]
            state.count++
        state

    _match_range_from_min: (beta, max, vdata, idx, state, func) ->
        while not max? or state.count < max
            @debug_log -> [ 'range', idx + state.progress, 'i='+state.count,
                '>=min %s'.sprintf(if state.greedy then 'greedy' else 'non-greedy') ]
            m = beta.op.call this, vdata, idx + state.progress
            break unless m?
            state.progress += m[0]
            state.work.push m[1]
            state.count++
            if output = func()
                return output
        return

    _match_range_suffix: (suffix, vdata, idx, state) ->
        if suffix?
            if (m = suffix.op.call this, vdata, idx + state.progress)?
                state.progress += m[0]
                state.work.push m[1]
                @debug_log -> [ 'range', idx + state.progress, 'success',
                    'count=%d %s'.sprintf(state.count, (if state.greedy then 'greedy' else 'non-greedy')) ]
                return [ state.progress, { pos: idx, length: state.progress, type: 'seq', seq: state.work } ]
            else
                return
        else
            @debug_log -> [ 'range', idx + state.progress, 'success',
                'count=%d %s'.sprintf(state.count, (if state.greedy then 'greedy' else 'non-greedy trivial')) ]
            return [ state.progress, { pos: idx, length: state.progress, type: 'seq', seq: state.work } ]

    @match_re: (rre, match_name) -> (vdata, idx) ->
        m = rre.exec @str.substr idx
        if m
            @debug_log -> [ 're', idx, 'success', @strip_quotes inspect rre.source ]
            vdata[match_name] = m[0..-1] if match_name?
            [ m[0].length, { pos: idx, length: m[0].length, type: 're', match: m[0], groups: m[0..-1] } ]
        else
            @debug_log -> [ 're', idx, 'fail', @strip_quotes inspect rre.source ]
            return

    @match_seq: (beta_seq...) ->
        (vdata, idx) ->
            @debug_log -> [ 'seq', idx, 'begin', (beta.name for beta in beta_seq) ]
            progress = 0
            work = [ ]
            i = 0
            for beta in beta_seq
                @debug_log -> [ 'seq', idx + progress, 'i='+i, beta.name ]
                m = beta.op.call this, vdata, idx + progress
                unless m?
                    @debug_log -> [ 'seq', idx + progress, 'fail' ]
                    return
                progress += m[0]
                work.push m[1]
                i++
            @debug_log -> [ 'seq', idx + progress, 'success' ]
            [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]

    @match_v: (alpha_s, argf) -> (vdata, idx) ->
        @debug_log -> [ 'v', idx, 'begin', alpha_s ]
        new_vdata = { }
        new_vdata.arg = argf.call this, vdata if argf?
        m = @vcache(alpha_s, idx, new_vdata)
        @debug_log -> [ 'v', idx + (if m? then m[0] else 0), (if m? then 'success' else 'fail'), alpha_s ]
        m

    @match_var_re: (re_str, match_name) ->
        self = this
        (vdata, idx) ->
            self.match_re(RegExp('^(?:' + @replace_backreferences(re_str, vdata) + ')'), match_name).call this, vdata, idx

    @op_transform: (f, beta) -> (vdata, idx) ->
        @debug_log -> [ 'transform', idx, 'begin', beta.name ]
        m = beta.op.call this, vdata, idx
        unless m?
            @debug_log -> [ 'transform', idx, 'fail', beta.name ]
            return
        tm = f.call this, m[1], vdata, idx
        unless tm?
            @debug_log -> [ 'transform', idx + m[0], 'fail', 'transform' ]
            return
        @debug_log -> [ 'transform', idx + m[0], 'success' ]
        [ m[0], tm ]

    parse: (str) ->
        @str = str
        @v_cache = {}
        @debug_log -> [ 'parse', 0, 'begin' ]
        doc = @Document { }, 0
        unless doc?
            @debug_log -> [ 'parse', 0, 'fail' ]
            return
        @debug_log -> [ 'parse', doc[0], 'success' ]
        doc[1]

    replace_backreferences: (re_str, vdata) ->
        work = re_str
        while m = (/\\=([^\[]+)\[([0-9]+)\]/.exec(work))
            mstr = (vdata[m[1]] || [ ])[m[2]]
            mstr ?= ''
            work = work.substr(0, m.index) + re_quote(mstr) + work.substr(m.index + m[0].length)
        work

    string_abbrev: (start, n) ->
        istr = @str.substr(start)
        istr = @strip_quotes inspect istr
        if istr.length > n
            istr.substr(0, n - 3) + '...'
        else
            istr

    strip_quotes: (str) ->
        m = /^'(.*)'$/.exec(str)
        if m
            m[1]
        else
            str

    vcache: (alpha_s, idx, vdata) ->
        cache_key = [ alpha_s, idx, JSON.stringify(vdata) ].join('#')
        if @v_cache.hasOwnProperty(cache_key)
            @debug_log -> [ 'vcache', idx, 'cached' ]
            return @v_cache[cache_key]
        else
            @v_cache[cache_key] = this[alpha_s] vdata, idx

exports.Parser = Parser
