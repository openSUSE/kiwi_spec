BUNDLE   ?= bundle
RSPEC    ?= rspec
RST2HTML ?= rst2html

export PATH := bundle/ruby/1.9.1/bin:$(PATH)
export GEM_PATH := bundle/ruby/1.9.1/:$(GEM_PATH)

bootstrap:
	$(BUNDLE) install --standalone

kiwi_spec:
	$(BUNDLE) exec $(RSPEC) kiwi_spec.rb

README.html: README.rest
	$(RST2HTML) --verbose --strict --exit-status=1 $< $@

.PHONY: bootstrap kiwi_spec
