re_quote = require('regexp-quote')
inspect_orig = require('util').inspect
inspect = (x) -> inspect_orig(x, false, null)

class Parser
  @defp: (alpha_s, beta) ->
    this.prototype[alpha_s] = (vdata, idx) ->
      beta.op.call(this, vdata, idx)

  @def_grammar_op: (name, op_f) ->
    this[name] = (varargs) ->
      args = [].splice.call arguments, 0
      { name: name, op: if op_f? then op_f.apply this, args else this.prototype['match_' + name].apply this, args }

  @def_grammar_op 'at_least_one', (beta) -> this.prototype.match_range beta, 1
  @def_grammar_op 'first'
  @def_grammar_op 'range'
  @def_grammar_op 'range_nongreedy'
  @def_grammar_op 're', (re_str, match_name) -> this.prototype.match_re RegExp('^(?:' + re_str + ')'), match_name
  @def_grammar_op 'seq'
  @def_grammar_op 'transform', (f, beta) -> this.prototype.op_transform f, beta
  @def_grammar_op 'v'
  @def_grammar_op 'var_re'
  @def_grammar_op 'zero_or_more', (beta) -> this.prototype.match_range beta, 0

  @backref: (ref) -> (vdata) ->
    m = /^([^\[]*)\[([0-9]*)\]/.exec(ref)
    [ (vdata[m[1]] || [ ])[m[2]], ]

  match_first: (varargs) ->
    beta_seq = [].splice.call arguments, 0
    (vdata, idx) ->
      for beta in beta_seq
        m = beta.op.call this, vdata, idx
        return m if m?
      undefined

  match_range: (beta, min, max) -> (vdata, idx) ->
    count = 0
    progress = 0
    work = []
    while not max? or count < max
      m = beta.op.call this, vdata, idx + progress
      break unless m?
      progress += m[0]
      work.push m[1]
      count++
    return undefined if min? and count < min
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
