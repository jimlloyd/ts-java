.PHONY: install install-npm install-tsd documentation test testdata unittest cucumber
.PHONY: clean clean-obj clean-tsd clean-npm clean-js-map clean-unittest clean-cucumber
.PHONY: install-java-pkgs build-java-pkgs clean-java-pkgs

default: test

######
# JAVAPKGS are directories containing a pom.xml and a package.json in which ts-java will be run
# to generate a java.d.ts file. Keep the packages in alphabetical order.
# Note that cucumber tests depend on these packages being 'built' by the build-java-pkgs target.
JAVAPKGS=\
	reflection \
	tinkerpop \

JAVAPKGS_INSTALL=$(patsubst %,%-install,$(JAVAPKGS))
JAVAPKGS_JAVADTS=$(patsubst %,%/java.d.ts,$(JAVAPKGS))
JAVAPKGS_CLEAN=$(patsubst %,%-clean,$(JAVAPKGS))

.PHONY: $(JAVAPKGS_INSTALL) $(JAVAPKGS_CLEAN)

install-java-pkgs : $(JAVAPKGS_INSTALL)

build-java-pkgs : $(JAVAPKGS_JAVADTS)

clean-java-pkgs : $(JAVAPKGS_CLEAN)

$(JAVAPKGS_INSTALL): %-install:
	cd $* && mvn clean package

$(JAVAPKGS_JAVADTS): %/java.d.ts: bin/ts-java.sh
	cd $* && ../bin/ts-java.sh

$(JAVAPKGS_CLEAN): %-clean:
	cd $* && mvn clean
	rm -rf $*/java.d.ts $*/o

####
TS_SRC=$(filter-out %.d.ts,$(wildcard bin/*.ts lib/*.ts test/*.ts features/step_definitions/*.ts))
TS_OBJ=$(patsubst %.ts,%.js,$(TS_SRC))
TS_JSMAP=$(patsubst %.ts,%.js.map,$(TS_SRC))
TSC=./node_modules/.bin/tsc
TSC_OPTS=--module commonjs --target ES5 --sourceMap

###
FEATURES=$(wildcard features/*/*.feature)
FEATURES_RAN=$(patsubst %.feature,%.lastran,$(FEATURES))

$(FEATURES_RAN): $(JAVAPKGS_JAVADTS)

$(FEATURES_RAN): %.lastran: %.feature
	./node_modules/.bin/cucumber-js --tags '~@todo' --require features/step_definitions $<

####

all:
	$(MAKE) install
	$(MAKE) test documentation

documentation :
	node_modules/groc/bin/groc --except "**/node_modules/**" --except "o/**" --except "**/*.d.ts" "**/*.ts" README.md

test: unittest cucumber

unittest: $(TS_OBJ)
	node_modules/mocha/bin/mocha --timeout 5s --reporter=spec --ui tdd

cucumber: $(FEATURES_RAN)

%.js: %.ts
	node_modules/tslint/bin/tslint --config tslint.json --file $<
	$(TSC) $(TSC_OPTS) $<
	stat $@ > /dev/null

clean: clean-cucumber clean-doc clean-js-map clean-npm clean-obj clean-tsd clean-unittest clean-java-pkgs

clean-cucumber:
	rm -rf o.features

clean-doc:
	rm -rf doc

clean-js-map:
	rm -f $(TS_JSMAP)

clean-npm:
	rm -rf node_modules

clean-obj:
	rm -f $(TS_OBJ)

clean-tsd:
	rm -rf typings

clean-unittest:
	rm -rf o/*

install: install-tsd install-java-pkgs

install-npm:
	npm install

TSD=./node_modules/.bin/tsd

install-tsd: install-npm
	$(TSD) reinstall

#####
# Explicit dependencies for files that are referenced

bin/*.js lib/*.js test/*.js: lib/java.d.ts

bin/ts-java.sh: $(TS_OBJ)
	touch $@

bin/ts-java.js : lib/*.ts

lib/classes-map.js : lib/work.ts

lib/code-writer.js : lib/classes-map.ts


