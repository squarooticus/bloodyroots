REPORTER = "dot"

COFFEE_SRC=$(wildcard coffee/*.coffee)
COFFEE_BUILD=$(patsubst coffee/%.coffee,lib/%.js,$(COFFEE_SRC))

build: $(COFFEE_BUILD) bloodyroots.js

$(COFFEE_BUILD) : lib/%.js : coffee/%.coffee
	coffee -c -o $(dir $@) $<

bloodyroots.js: $(COFFEE_BUILD) node_modules
	./node_modules/.bin/browserify lib/bloodyroots.js >$@

node_modules:
	npm install

.PHONY: test

test:
	NODE_ENV=test ./node_modules/.bin/mocha --compilers coffee:coffee-script --reporter $(REPORTER) --colors test/parser.coffee

TEST_SRC=$(wildcard test/*.coffee)
TEST_BUILD=$(patsubst test/%.coffee,test_lib/%.js,$(TEST_SRC))
TEST_BROWSER_BUILD=$(patsubst test/%.coffee,test_lib/%.browser.js,$(TEST_SRC))

browser-test: build $(TEST_BROWSER_BUILD)

$(TEST_BROWSER_BUILD) : test_lib/%.browser.js : test_lib/%.js
	./node_modules/.bin/browserify $< >$@

$(TEST_BUILD) : test_lib/%.js : test/%.coffee
	coffee -c -o $(dir $@) $<

clean:
	rm -rf node_modules
	rm -f bloodyroots*.t*z* *.log $(COFFEE_BUILD) bloodyroots.js $(TEST_BUILD) $(TEST_BROWSER_BUILD)
	-rmdir lib test_lib
