global.inspect_orig = require('util').inspect
global.inspect = (x) -> inspect_orig(x, false, null)
global.deep_equal = require('deep-equal')
global.assert = require('chai').assert
global.expect = require('chai').expect
global.should = require('chai').should

