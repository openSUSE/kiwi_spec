kiwi\_spec
==========

KIWI acceptance testing based on RSpec

Instructions
------------

### Installation ###

`make bootstrap` command will install all the required dependencies.

### Configuration ###

A valid authorized\_keys file should be placed in
`root/root/.ssh/authorized_keys`.

Then, copy the cfg/\*.sample files by removing the .sample suffix,
and edit them accordingly. You should have the following files present:
* `cfg/config.xml.template`
* `cfg/kiwi.yml`
Finally, replace `#{arch}` placeholder with the desired value in config.xml.template.

### Run ###

`make kiwi_spec` will run the RSpec tests.
