REPORTER = "list"

{exec} = require 'child_process'
 
task "build", "build the files", ->
  exec "coffee -c -o lib/ src/", (err, output) ->
    throw err if err
    console.log output

task "watch", "watch and build the files", ->
  exec "coffee -cw -o lib/ src/"

task "clean", "clean the source directory", ->
  exec "rm -rf lib node_modules *.log"

task "test", "run tests", ->
  exec "NODE_ENV=test 
    ./node_modules/.bin/mocha 
    --compilers coffee:coffee-script
    --reporter #{REPORTER}
    --require coffee-script
    --require should
    --require test/test_helper.coffee
    --colors
  ", (err, output) ->
    throw err if err
    console.log output

