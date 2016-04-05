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

