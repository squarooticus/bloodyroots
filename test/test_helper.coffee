global.inspect_orig = require('util').inspect
global.inspect = (x) -> inspect_orig(x, false, null)
global.deep_equal = require('deep-equal')
chai = require('chai')
global.assert = chai.assert
global.expect = chai.expect
global.should = chai.should
global.Parser = require('../build/bloodyroots.js').Parser
