# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2018 Michael Daum http://michaeldaumconsulting.com
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
use warnings;

our $VERSION = '8.20';
our $RELEASE = '26 Nov 2018';
our $SHORTDESCRIPTION = 'Improved interaction with attachments and !DataForms';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

use Foswiki::Func ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Request();

BEGIN {
    # Backwards compatibility for Foswiki 1.1.x
    unless ( Foswiki::Request->can('multi_param') ) {
        no warnings 'redefine';
        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
        use warnings 'redefine';
    }
}

##############################################################################
sub initPlugin {

  Foswiki::Func::registerTagHandler('ATTACHMENTS', sub {
    require Foswiki::Plugins::TopicInteractionPlugin::Attachments;
    return Foswiki::Plugins::TopicInteractionPlugin::Attachments::handle(@_);
  });

  # compatibility with AttachmentListPlugin
  Foswiki::Func::registerTagHandler('ATTACHMENTLIST', sub {
    require Foswiki::Plugins::TopicInteractionPlugin::Attachments;
    return Foswiki::Plugins::TopicInteractionPlugin::Attachments::handle(@_, 1);
  });

  Foswiki::Func::registerTagHandler('WEBDAVURL', sub {
    require Foswiki::Plugins::TopicInteractionPlugin::WebDAVUrl;
    return Foswiki::Plugins::TopicInteractionPlugin::WebDAVUrl::handle(@_);
  });

  Foswiki::Func::registerRESTHandler('changeproperties', sub { 
      return getCore(shift)->restChangeProperties(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('delete', sub {
      return getCore(shift)->restDelete(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('move', sub {
      return getCore(shift)->restMove(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('upload', sub {
      return getCore(shift)->restUpload(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('createlink', sub {
      return getCore(shift)->restCreateLink(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('createimagegallery', sub {
      return getCore(shift)->restCreateImageGallery(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('download', sub {
      return getCore(shift)->restDownload(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('hide', sub {
      return getCore(shift)->restHide(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('unhide', sub {
      return getCore(shift)->restUnhide(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  # just in case it did not make it to LocalSite.cfg in time
  Foswiki::Plugins::JQueryPlugin::registerPlugin("uploader", 'Foswiki::Plugins::TopicInteractionPlugin::Uploader');

  # init 
  getCore();

  return 1;
}

##############################################################################
sub finishPlugin {
  undef $core;
}
##############################################################################
sub getCore {
  my $session = shift;

  unless ($core) {
    require Foswiki::Plugins::TopicInteractionPlugin::Core;
    $core = Foswiki::Plugins::TopicInteractionPlugin::Core->new($session);
  }

  return $core;
}

##############################################################################
# keep a t=thumbnail attr in attachments
sub beforeUploadHandler {
  my ($attachment, $meta) = @_;

  my $oldAttachment = $meta->get("FILEATTACHMENT", $attachment->{name});

  if ($oldAttachment && $oldAttachment->{attr} && ($oldAttachment->{attr} || '') =~ /t/) {
    $attachment->{isthumbnail} = 1;
  }
}

##############################################################################
sub afterUploadHandler {
  my ($attachment, $meta) = @_;

  if ($attachment->{isthumbnail}) {
    delete $attachment->{isthumbnail};

    my $oldAttr = $attachment->{attr} || '';
    my %attrs = map {$_=>1} split(//, $oldAttr);
    $attrs{t} = 1;
    my $newAttr = join("", sort keys %attrs);
    if ($oldAttr ne $newAttr) {
      $attachment->{attr} = $newAttr;
      $meta->putKeyed("FILEATTACHMENT", $attachment);
      $meta->save();
    }
  }
}


1;
