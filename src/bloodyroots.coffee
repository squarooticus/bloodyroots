re_quote = require('regexp-quote')
inspect_orig = require('util').inspect
inspect = (x) -> inspect_orig(x, false, null)
require('sprintf.js')

class Parser
  @define_production: (alpha_s, beta) ->
    @prototype[alpha_s] = (vdata, idx) ->
      beta.op.call(this, vdata, idx)

  @define_grammar_operation: (name, op_f) ->
    this[name] = (varargs) ->
      args = [].splice.call arguments, 0
      { name: name, op: if op_f? then op_f.apply this, args else @prototype['match_' + name].apply this, args }

  @define_grammar_operation 'at_least_one', (beta) -> @prototype.match_range beta, 1
  @define_grammar_operation 'alternation'
  @define_grammar_operation 'range'
  @define_grammar_operation 'range_nongreedy'
  @define_grammar_operation 're', (re_str, match_name) -> @prototype.match_re RegExp('^(?:' + re_str + ')'), match_name
  @define_grammar_operation 'seq'
  @define_grammar_operation 'transform', (f, beta) -> @prototype.op_transform f, beta
  @define_grammar_operation 'v'
  @define_grammar_operation 'var_re'
  @define_grammar_operation 'zero_or_more', (beta) -> @prototype.match_range beta, 0

  @backref: (ref) -> (vdata) ->
    m = /^([^\[]*)\[([0-9]*)\]/.exec(ref)
    [ (vdata[m[1]] || [ ])[m[2]], ]

  debug_log: (f) ->
    if this.constructor.debug
      [ name, idx, outcome, data ] = f()
      '%-15s: %3s %-25s %-8s %s\n'.printf name, idx, this.string_abbrev(idx, 25), outcome || '', data || ''

  string_abbrev: (start, n) ->
    istr = inspect @str
    istr = istr.substr 1, istr.length-2
    if istr.length < start + n
      istr.substr(start)
    else
      istr.substr(start, n - 3) + '...'

  match_alternation: (varargs) ->
    beta_seq = [].splice.call arguments, 0
    (vdata, idx) ->
      this.debug_log -> [ 'alternation', idx, 'begin', [ beta.name for beta in beta_seq ] ]
      i = 0
      for beta in beta_seq
        this.debug_log -> [ 'alternation', idx, 'i='+i, beta.name ]
        m = beta.op.call this, vdata, idx
        if m?
          this.debug_log -> [ 'alternation', idx, 'success' ]
          return m
        i++
      this.debug_log -> [ 'alternation', idx, 'fail' ]
      undefined

  match_range: (beta, min, max) -> (vdata, idx) ->
    this.debug_log -> [ 'range', idx, 'begin', '%s min=%d max=%d'.sprintf beta.name, min, max ]
    count = 0
    progress = 0
    work = []
    while not max? or count < max
      this.debug_log -> [ 'range', idx, 'i='+count ]
      m = beta.op.call this, vdata, idx + progress
      break unless m?
      progress += m[0]
      work.push m[1]
      count++
    if min? and count < min
      this.debug_log -> [ 'range', idx, 'fail' ]
      return undefined
    this.debug_log -> [ 'range', idx, 'success', 'count=%d'.sprintf count ]
    [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]

  match_range_nongreedy: (beta, min, max, suffix) -> (vdata, idx) ->
    count = 0
    progress = 0
    work = []
    while not max? or count < max
      m = beta.op.call this, vdata, idx + progress
      break unless m?
      progress += m[0]
      work.push m[1]
      count++
      if not min? or count >= min
        m2 = suffix.op.call this, vdata, idx + progress
        if m2?
          progress += m2[0]
          work.push m2[1]
          return [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]
    undefined

  match_re: (rre, match_name) -> (vdata, idx) ->
    m = rre.exec @str.substr idx
    if m
      vdata[match_name] = m[0..-1] if match_name?
      [ m[0].length, { pos: idx, length: m[0].length, type: 're', match: m[0], groups: m[0..-1] } ]
    else
      undefined

  match_seq: (varargs) ->
    beta_seq = [].splice.call arguments, 0
    (vdata, idx) ->
      progress = 0
      work = [ ]
      for beta in beta_seq
        m = beta.op.call this, vdata, idx + progress
        return undefined unless m?
        progress += m[0]
        work.push m[1]
      [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]

  match_v: (alpha_s, argf) -> (vdata, idx) ->
    new_vdata = { }
    new_vdata.arg = argf.call this, vdata if argf?
    this[alpha_s] new_vdata, idx

  match_var_re: (re_str, match_name) -> (vdata, idx) ->
    this.match_re(RegExp('^(?:' + this.replace_backreferences(re_str, vdata) + ')'), match_name).call this, vdata, idx

  op_transform: (f, beta) -> (vdata, idx) ->
    m = beta.op.call this, vdata, idx
    return undefined unless m?
    tm = f m[1], vdata, idx
    return undefined unless tm?
    [ m[0], tm ]

  parse: (str) ->
    @str = str
    doc = this.Document { }, 0
    return undefined unless doc?
    doc[1]

  replace_backreferences: (re_str, vdata) ->
    work = re_str
    while m = (/\\=([^\[]+)\[([0-9]+)\]/.exec(work))
      mstr = (vdata[m[1]] || [ ])[m[2]]
      mstr ?= ''
      work = work.substr(0, m.index) + re_quote(mstr) + work.substr(m.index + m[0].length)
    work

exports.Parser = Parser
