BUNDLE   ?= bundle
RSPEC    ?= rspec

export PATH := bundle/ruby/1.9.1/bin:$(PATH)
export GEM_PATH := bundle/ruby/1.9.1/:$(GEM_PATH)

bootstrap:
	$(BUNDLE) install --standalone

kiwi_spec:
	$(RSPEC) kiwi_spec.rb

.PHONY: bootstrap kiwi_spec
