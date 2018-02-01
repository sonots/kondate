# 0.4.15 (2018-02-01)

Changes:

* Remove `bundle exec` from `bundle exec itamae` because `bundle exec` inside `bundle exec` introcudes some troubles.

# 0.4.14 (2017-03-27)

Reverts:

* Fallback to ENV['USER'] rather than Etc.getlogin if ssh_config[:ssh_user] is not available

# 0.4.13 (2017-03-27)

Enhancements:

* Fix to see all Net::SSH::Config keys in itamae

# 0.4.12 (2017-03-17)

Enhancements:

* Output Net::SSH::Config.for(host) as debug log

# 0.4.11 (2017-03-09)

Enhancements:

* Use Parallel::ProcessorCount instead of Facter gem

# 0.4.10 (2017-03-09)

Fixes:

* Fix Net::SSH::Config ssh_keys

# 0.4.9 (2017-02-02)

Enhancements:

* Add hostname to itamae log prefix without using IO.pipe so that we can use debuggers such as pry

# 0.4.8 (2017-01-27)

Enhancements:

* Add hostname to itamae log prefix

# 0.4.7 (2017-01-26)

Fixes:

* Revert 0.4.5 to avoid No such file or directory ...

# 0.4.6 (2017-01-25)

Enhancements:

* Mask private rsa key

# 0.4.5 (2017-01-23)

Fixes:

* Remove tempfile created

# 0.4.4 (2016-12-02)

Changes:

* Prepare `Kondate::ItamaeBootstrap.bootstrap(context)`. Now, bootstrap.rb should just call it.

# 0.4.3 (2016-12-02)

Fixes:

* Fixe nil error

# 0.4.2 (2016-12-01)

Enhancements:

* Support secret recipes and spec files

# 0.4.1 (2016-12-01)

Fixes:

* The order of exploring possible role files was opposite

# 0.4.0 (2016-12-01)

Enhancements:

* Add a feature to explore possible role files

# 0.3.3 (2016-11-20)

Changes:

* kondate init now requires a target_dir argument, not an option anymore

# 0.3.2 (2016-11-18)

Fixes:

* Revert log message

# 0.3.1 (2016-11-18)

Fixes:

* Fix to remove temporary property files properly

# 0.3.0 (2016-11-18)

Enhancements:

* Add itamae-role and serverspec-role subcommands to run for multiple hosts in parallel

# 0.2.1 (2016-11-14)

Fixes:

* Resolve 'failed to load rake command' when kondate init (thanks to @mazgi)

# 0.2.0 (2016-04-05)

Enhancments:

* Support arbitrary hostinfo by HostPlugin

# 0.1.9 (2015-12-11)

Enhancments:

* Support itamae --profile option
* Support itamae --recipe-graph option

# 0.1.8 (2015-12-09)

Changes:

* kondate generate => kondate init (as itamae init)

# 0.1.7 (2015-12-06)

Fixes:

* Fix typo

# 0.1.6 (2015-11-30)

Fixes:

* Fix regression (avoid nil error) introduced in 0.1.4

# 0.1.5 (2015-11-30)

Changes:

* Add --vagrant option, and stop judging vagrant or not via host name

# 0.1.4 (2015-11-29)

Changes:

* Define global_attributes instead of using attributes['global']
* Let vagrant? to handle inside each host plugin

# 0.1.3 (2015-11-26)

Fixes:

* Fix to keep global attributes with --recipe

# 0.1.2 (2015-11-24)

Enhancments:

* Support environments properties.

# 0.1.1 (2015-11-24)

Changes:

* Do not open Hash class to add deep_merge, instead use own HashExt class.

# 0.1.0 (2015-11-23)

first version

