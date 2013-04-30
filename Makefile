REPORTER = "dot"

COFFEE_SRC=$(wildcard coffee/*.coffee)
COFFEE_BUILD=$(patsubst coffee/%.coffee,build/%.js,$(COFFEE_SRC))

build: $(COFFEE_BUILD)

$(COFFEE_BUILD) : build/%.js : coffee/%.coffee
	coffee -c -o $(dir $@) $<

clean:
	rm -rf build node_modules
	rm -f bloodyroots*.t*z* *.log

.PHONY: test

test:
	./node_modules/.bin/mocha --compilers coffee:coffee-script --reporter $(REPORTER) --require coffee-script --require should --require test/test_helper.coffee --colors test/parser.coffee

