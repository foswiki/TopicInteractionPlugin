# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2010 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TopicInteractionPlugin;

use strict;

our $VERSION = '$Rev: 1340 $';
our $RELEASE = '2.00';
our $SHORTDESCRIPTION = 'Improved interaction with attachments and !DataForms';
our $NO_PREFS_IN_TOPIC = 1;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();

##############################################################################
sub initPlugin {

  Foswiki::Func::registerTagHandler('UPLOADFORM', \&handleUPLOADFORM);
  Foswiki::Func::registerTagHandler('ATTACHMENTS', \&handleATTACHMENTS);
  Foswiki::Func::registerRESTHandler('handle', \&handleRest);

  Foswiki::Plugins::JQueryPlugin::registerPlugin("uploader", 'Foswiki::Plugins::TopicInteractionPlugin::Uploader');

  return 1;
}

##############################################################################
sub handleATTACHMENTS {
  require Foswiki::Plugins::TopicInteractionPlugin::Attachments;
  return Foswiki::Plugins::TopicInteractionPlugin::Attachments::handle(@_);
}

##############################################################################
sub handleUPLOADFORM {
  require Foswiki::Plugins::TopicInteractionPlugin::UploadForm;
  return Foswiki::Plugins::TopicInteractionPlugin::UploadForm::handle(@_);
}

##############################################################################
sub handleRest {
  require Foswiki::Plugins::TopicInteractionPlugin::Core;
  return Foswiki::Plugins::TopicInteractionPlugin::Core::handleRest(@_);
}

1;
