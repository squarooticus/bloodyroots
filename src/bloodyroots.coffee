re_quote = require('regexp-quote')
inspect_orig = require('util').inspect
inspect = (x) -> inspect_orig(x, false, null)

class Parser
  @defp: (alpha_s, beta) ->
    this.prototype[alpha_s] = (vdata, idx) -> beta.op.call(this, vdata, idx)

  @at_least_one: (beta) ->
    {
      type: 'range',
      op: this.prototype.match_range(beta, 1),
    }

  @first: (varargs) ->
    beta_seq = [].splice.call(arguments,0)
    {
      type: 'first',
      op: this.prototype.match_first(beta_seq),
    }

  @range: (beta, min, max) ->
    {
      type: 'range',
      op: this.prototype.match_range(beta, min, max),
    }

  @range_nongreedy: (beta, min, max, suffix) ->
    {
      type: 'range_nongreedy',
      op: this.prototype.match_range_nongreedy(beta, min, max, suffix),
    }

  @re: (re_str, match_name) ->
    {
      type: 're',
      op: this.prototype.match_re(RegExp('^(?:' + re_str + ')'), match_name),
    }

  @seq: (varargs) ->
    beta_seq = [].splice.call(arguments,0)
    {
      type: 'seq',
      op: this.prototype.match_seq(beta_seq),
    }

  @transform: (f, beta) ->
    {
      type: 'transform',
      op: this.prototype.op_transform(f, beta),
    }

  @v: (alpha_s, argf) ->
    {
      type: 'v',
      op: this.prototype.match_v(alpha_s, argf),
    }

  @var_re: (re_str, match_name) ->
    {
      type: 'var_re',
      op: this.prototype.match_var_re(re_str, match_name),
    }

  @zero_or_more: (beta) ->
    {
      type: 'range',
      op: this.prototype.match_range(beta, 0),
    }

  @backref: (ref) -> (vdata) ->
    m = /^([^\[]*)\[([0-9]*)\]/.exec(ref)
    [ (vdata[m[1]] || [ ])[m[2]], ]

  match_first: (beta_seq) -> (vdata, idx) ->
    for beta in beta_seq
      m = beta.op.call(this, vdata, idx)
      return m if m?
    undefined

  match_range: (beta, min, max) -> (vdata, idx) ->
    count = 0
    progress = 0
    work = []
    while not max? or count < max
      m = beta.op.call(this, vdata, idx + progress)
      break unless m?
      progress += m[0]
      work.push(m[1])
      count++
    return undefined if min? and count < min
    [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]

  match_range_nongreedy: (beta, min, max, suffix) -> (vdata, idx) ->
    count = 0
    progress = 0
    work = []
    while not max? or count < max
      m = beta.op.call(this, vdata, idx + progress)
      break unless m?
      progress += m[0]
      work.push(m[1])
      count++
      if not min? or count >= min
        m2 = suffix.op.call(this, vdata, idx + progress)
        if m2?
          progress += m2[0]
          work.push(m2[1])
          return [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]
    undefined

  match_re: (rre, match_name) -> (vdata, idx) ->
    m = rre.exec(@str.substr(idx))
    if m
      vdata[match_name] = m[0..-1] if match_name?
      [ m[0].length, { pos: idx, length: m[0].length, type: 're', match: m[0], groups: m[0..-1] } ]
    else
      undefined

  match_seq: (beta_seq) -> (vdata, idx) ->
    progress = 0
    work = [ ]
    for beta in beta_seq
      m = beta.op.call(this, vdata, idx + progress)
      return undefined unless m?
      progress += m[0]
      work.push(m[1])
    [ progress, { pos: idx, length: progress, type: 'seq', seq: work } ]

  match_v: (alpha_s, argf) -> (vdata, idx) ->
    new_vdata = { }
    new_vdata.arg = argf.call(this, vdata) if argf?
    this[alpha_s](new_vdata, idx)

  match_var_re: (re_str, match_name) -> (vdata, idx) ->
    this.match_re(RegExp('^(?:' + this.replace_backreferences(re_str, vdata) + ')'), match_name).call(this, vdata, idx)

  op_transform: (f, beta) -> (vdata, idx) ->
    m = beta.op.call(this, vdata, idx)
    return undefined unless m?
    tm = f(m[1], vdata, idx)
    return undefined unless tm?
    [ m[0], tm ]

  parse: (str) ->
    @str = str
    doc = this.Document({ }, 0)
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
