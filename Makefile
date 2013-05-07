REPORTER=dot
BROWSERIFY=./node_modules/.bin/browserify
MOCHA=./node_modules/.bin/mocha
COFFEE=./node_modules/.bin/coffee

COFFEE_SRC=$(wildcard coffee/*.coffee)
COFFEE_BUILD=$(patsubst coffee/%.coffee,lib/%.js,$(COFFEE_SRC))

build: $(COFFEE_BUILD) bloodyroots.js

$(COFFEE_BUILD): node_modules
$(COFFEE_BUILD) : lib/%.js : coffee/%.coffee
	$(COFFEE) -c -o $(dir $@) $<

bloodyroots.js: $(COFFEE_BUILD) node_modules
	$(BROWSERIFY) lib/bloodyroots.js >$@

node_modules:
	npm install

.PHONY: test

test:
	NODE_ENV=test $(MOCHA) --compilers coffee:coffee-script --reporter $(REPORTER) --colors test/parser.coffee

TEST_SRC=$(wildcard test/*.coffee)
TEST_BUILD=$(patsubst test/%.coffee,test_lib/%.js,$(TEST_SRC))
TEST_BROWSER_BUILD=$(patsubst test/%.coffee,test_lib/%.browser.js,$(TEST_SRC))

browser-test: build $(TEST_BROWSER_BUILD)

$(TEST_BROWSER_BUILD) : test_lib/%.browser.js : test_lib/%.js
	$(BROWSERIFY) $< >$@

$(TEST_BUILD): node_modules
$(TEST_BUILD) : test_lib/%.js : test/%.coffee
	$(COFFEE) -c -o $(dir $@) $<

clean:
	rm -rf node_modules
	rm -f bloodyroots*.t*z* *.log $(COFFEE_BUILD) bloodyroots.js $(TEST_BUILD) $(TEST_BROWSER_BUILD)
	-rmdir lib test_lib
