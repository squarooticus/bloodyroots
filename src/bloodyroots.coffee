re_quote = require('regexp-quote')
inspect_orig = require('util').inspect
inspect = (x) -> inspect_orig(x, false, null)
require('sprintf.js')
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

class Parser
  @define_production: (alpha_s, beta) ->
    @prototype[alpha_s] = (vdata, idx) ->
      beta.op.call(this, vdata, idx)

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
    if this.constructor.debug
      [ name, idx, outcome, data ] = f.call(this)
      '%-15s %3s %-25s %-8s %s\n'.printf name, idx, this.string_abbrev(idx, 25), outcome || '', data || ''

  @match_alternation: (varargs) ->
    if typeIsArray varargs
      beta_seq = varargs
      suffix = arguments[1]
    else
      beta_seq = [].splice.call arguments, 0
    (vdata, idx) ->
      this.debug_log -> [ 'alternation', idx, 'begin', 'alternation=%s%s'.sprintf (beta.name for beta in beta_seq), (if suffix? then ' suffix='+suffix.name else ' no-suffix') ]
      i = 0
      for beta in beta_seq
        this.debug_log -> [ 'alternation', idx, 'i='+i, beta.name ]
        m = beta.op.call this, vdata, idx
        if m?
          if suffix?
            m2 = suffix.op.call this, vdata, idx + m[0]
            if m2?
              this.debug_log -> [ 'alternation', idx + m[0] + m2[0], 'success', 'count='+(i+1) ]
              return [ m[0] + m2[0], { pos: idx, length: m[0] + m2[0], type: 'seq', seq: [ m[1], m2[1] ] } ]
          else
            this.debug_log -> [ 'alternation', idx + m[0], 'success', 'count=%d'.sprintf (i+1) ]
            return m
        i++
      this.debug_log -> [ 'alternation', idx, 'fail' ]
      undefined

  @match_range: (beta, min=0, max, greedy=true, suffix) ->
    if greedy
      @match_greedy_range(beta, min, max, suffix)
    else
      @match_nongreedy_range(beta, min, max, suffix)

  @match_greedy_range: (beta, min, max, suffix) -> (vdata, idx) ->
    return unless state = @_begin_range_match(beta, min, max, true, vdata, idx)
    greedy_progress = [ state.progress ]
    @_range_matcher beta, max, vdata, idx, state, =>
      greedy_progress.push(state.progress)
      false
    while greedy_progress.length
      state.progress = greedy_progress.pop()
      this.debug_log -> [ 'range', idx + state.progress, 'i='+state.count, 'greedy backtracking' ]
      return result if result = @_match_range_suffix(suffix, vdata, idx, state)
      state.work.pop()
      state.count--
    this.debug_log -> [ 'range', idx + state.progress, 'fail', 'greedy backtracking' ]
    undefined

  @match_nongreedy_range: (beta, min, max, suffix) -> (vdata, idx) ->
    return unless state = @_begin_range_match(beta, min, max, false, vdata, idx)
    @_match_range_suffix(suffix, vdata, idx, state) or @_range_matcher(beta, max, vdata, idx, state, =>
      if (m = suffix.op.call this, vdata, idx + state.progress)?
        state.progress += m[0]
        state.work.push m[1]
        this.debug_log -> [ 'range', idx + state.progress, 'success', 'count=%d non-greedy'.sprintf(state.count) ]
        return [ state.progress, { pos: idx, length: state.progress, type: 'seq', seq: state.work } ]
    ) or (this.debug_log( -> [ 'range', idx + state.progress, 'fail', '>=min non-greedy' ]); undefined)

  _begin_range_match: (beta, min, max, greedy, vdata, idx) ->
    this.debug_log -> [ 'range', idx, 'begin',
    '%s min=%s max=%s greedy=%s%s'.sprintf beta.name, min, (if max? then max else ''),
      greedy, (if suffix? then ' suffix='+suffix.name else ' no-suffix') ]
    return if max? and min > max
    r = {count: 0, progress: 0, work: []}
    while r.count < min
      this.debug_log -> [ 'range', idx + r.progress, 'i='+r.count, '<min' ]
      m = beta.op.call this, vdata, idx + r.progress
      unless m?
        this.debug_log -> [ 'range', idx + r.progress, 'fail' ]
        return
      r.progress += m[0]
      r.work.push m[1]
      r.count++
    r

  _match_range_suffix: (suffix, vdata, idx, state) ->
    unless suffix?
      this.debug_log -> [ 'range', idx + state.progress, 'success', 'count=%d non-greedy no-suffix trivial'.sprintf(state.count) ]
      return [ state.progress, { pos: idx, length: state.progress, type: 'seq', seq: state.work } ]
    if suffix? and (m = suffix.op.call this, vdata, idx + state.progress)?
      state.progress += m[0]
      state.work.push m[1]
      this.debug_log -> [ 'range', idx + state.progress, 'success', 'count=%d non-greedy'.sprintf(state.count) ]
      return [ state.progress, { pos: idx, length: state.progress, type: 'seq', seq: state.work } ]

  _range_matcher: (beta, max, vdata, idx, state, func) ->
    while not max? or state.count < max
      this.debug_log -> [ 'range', idx + state.progress, 'i='+state.count, '>=min' ]
      m = beta.op.call this, vdata, idx + state.progress
      break unless m?
      state.progress += m[0]
      state.work.push m[1]
      state.count++
      if output = func()
        return output
    undefined

  @match_re: (rre, match_name) -> (vdata, idx) ->
    m = rre.exec @str.substr idx
    if m
      this.debug_log -> [ 're', idx, 'success', this.strip_quotes inspect rre.source ]
      vdata[match_name] = m[0..-1] if match_name?
      [ m[0].length, { pos: idx, length: m[0].length, type: 're', match: m[0], groups: m[0..-1] } ]
    else
      this.debug_log -> [ 're', idx, 'fail', this.strip_quotes inspect rre.source ]
      undefined

  @match_seq: (beta_seq...) ->
    (vdata, idx) ->
      this.debug_log -> [ 'seq', idx, 'begin', (beta.name for beta in beta_seq) ]
      progress = 0
      work = [ ]
      i = 0
      for beta in beta_seq
        this.debug_log -> [ 'seq', idx + progress, 'i='+i, beta.name ]
        m = beta.op.call this, vdata, idx + progress
        unless m?
          this.debug_log -> [ 'seq', idx + progress, 'fail' ]
          return undefined
        progress += m[0]
        work.push m[1]
        i++
      this.debug_log -> [ 'seq', idx + progress, 'success' ]
      [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]

  @match_v: (alpha_s, argf) -> (vdata, idx) ->
    this.debug_log -> [ 'v', idx, 'begin', alpha_s ]
    new_vdata = { }
    new_vdata.arg = argf.call this, vdata if argf?
    m = this.vcache(alpha_s, idx, new_vdata)
    this.debug_log -> [ 'v', idx + (if m? then m[0] else 0), (if m? then 'success' else 'fail'), alpha_s ]
    m

  @match_var_re: (re_str, match_name) ->
    self = this
    (vdata, idx) ->
      self.match_re(RegExp('^(?:' + this.replace_backreferences(re_str, vdata) + ')'), match_name).call this, vdata, idx

  @op_transform: (f, beta) -> (vdata, idx) ->
    this.debug_log -> [ 'transform', idx, 'begin', beta.name ]
    m = beta.op.call this, vdata, idx
    unless m?
      this.debug_log -> [ 'transform', idx, 'fail', beta.name ]
      return undefined
    tm = f.call this, m[1], vdata, idx
    unless tm?
      this.debug_log -> [ 'transform', idx + m[0], 'fail', 'transform' ]
      return undefined
    this.debug_log -> [ 'transform', idx + m[0], 'success' ]
    [ m[0], tm ]

  parse: (str) ->
    @str = str
    @v_cache = {}
    this.debug_log -> [ 'parse', 0, 'begin' ]
    doc = this.Document { }, 0
    unless doc?
      this.debug_log -> [ 'parse', 0, 'fail' ]
      return undefined
    this.debug_log -> [ 'parse', doc[0], 'success' ]
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
    istr = this.strip_quotes inspect istr
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
      this.debug_log -> [ 'vcache', idx, 'cached' ]
      return @v_cache[cache_key]
    else
      @v_cache[cache_key] = this[alpha_s] vdata, idx

exports.Parser = Parser
