REPORTER = "dot"

{exec} = require 'child_process'
 
task "build", "build the files", ->
  exec "coffee -c -o lib/ src/", (err, output) ->
    console.log output
    throw err if err

task "watch", "watch and build the files", ->
  exec "coffee -cw -o lib/ src/"

task "clean", "clean the source directory", ->
  exec "rm -rf lib node_modules *.log"

task "test", "run tests", ->
  exec "./node_modules/.bin/mocha 
    --compilers coffee:coffee-script
    --reporter #{REPORTER}
    --require coffee-script
    --require should
    --require test/test_helper.coffee
    --colors
    test/parser.coffee
  ", (err, output) ->
    console.log output
    throw err if err

